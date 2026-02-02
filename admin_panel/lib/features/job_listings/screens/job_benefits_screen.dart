import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/job_listings_admin_service.dart';

class JobBenefitsScreen extends ConsumerStatefulWidget {
  const JobBenefitsScreen({super.key});

  @override
  ConsumerState<JobBenefitsScreen> createState() => _JobBenefitsScreenState();
}

class _JobBenefitsScreenState extends ConsumerState<JobBenefitsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final benefitsAsync = ref.watch(jobBenefitsProvider);

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
                      'Yan Haklar',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'İş ilanlarında sunulan yan hakları yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(jobBenefitsProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showBenefitDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Yan Hak Ekle'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Search
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Yan hak ara...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Grid
            Expanded(
              child: benefitsAsync.when(
                data: (benefits) {
                  var filtered = benefits;
                  if (_searchQuery.isNotEmpty) {
                    filtered = filtered.where((b) =>
                      b.name.toLowerCase().contains(_searchQuery.toLowerCase())
                    ).toList();
                  }
                  return _buildBenefitsGrid(filtered);
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

  Widget _buildBenefitsGrid(List<JobBenefit> benefits) {
    if (benefits.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_giftcard_outlined, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text('Henüz yan hak yok', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.2,
      ),
      itemCount: benefits.length,
      itemBuilder: (context, index) => _buildBenefitCard(benefits[index]),
    );
  }

  Widget _buildBenefitCard(JobBenefit benefit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getIconData(benefit.iconName), color: AppColors.primary, size: 22),
              ),
              const Spacer(),
              _buildStatusBadge(benefit.isActive),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            benefit.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => _showBenefitDialog(benefit: benefit),
                icon: const Icon(Icons.edit, size: 18),
                tooltip: 'Düzenle',
                color: AppColors.info,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _deleteBenefit(benefit),
                icon: const Icon(Icons.delete, size: 18),
                tooltip: 'Sil',
                color: AppColors.error,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String? iconName) {
    const iconMap = {
      'card_giftcard': Icons.card_giftcard,
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'health_and_safety': Icons.health_and_safety,
      'fitness_center': Icons.fitness_center,
      'school': Icons.school,
      'child_care': Icons.child_care,
      'home': Icons.home,
      'phone_android': Icons.phone_android,
      'laptop': Icons.laptop,
      'flight': Icons.flight,
      'local_cafe': Icons.local_cafe,
      'sports_esports': Icons.sports_esports,
      'spa': Icons.spa,
      'attach_money': Icons.attach_money,
      'event': Icons.event,
    };
    return iconMap[iconName] ?? Icons.card_giftcard;
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Pasif',
        style: TextStyle(
          color: isActive ? AppColors.success : AppColors.error,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showBenefitDialog({JobBenefit? benefit}) {
    final isEdit = benefit != null;
    final nameController = TextEditingController(text: benefit?.name ?? '');
    final sortOrderController = TextEditingController(text: (benefit?.sortOrder ?? 0).toString());
    String selectedIcon = benefit?.iconName ?? 'card_giftcard';
    bool isActive = benefit?.isActive ?? true;

    final iconOptions = [
      {'name': 'card_giftcard', 'icon': Icons.card_giftcard},
      {'name': 'restaurant', 'icon': Icons.restaurant},
      {'name': 'directions_car', 'icon': Icons.directions_car},
      {'name': 'health_and_safety', 'icon': Icons.health_and_safety},
      {'name': 'fitness_center', 'icon': Icons.fitness_center},
      {'name': 'school', 'icon': Icons.school},
      {'name': 'child_care', 'icon': Icons.child_care},
      {'name': 'home', 'icon': Icons.home},
      {'name': 'phone_android', 'icon': Icons.phone_android},
      {'name': 'laptop', 'icon': Icons.laptop},
      {'name': 'flight', 'icon': Icons.flight},
      {'name': 'local_cafe', 'icon': Icons.local_cafe},
      {'name': 'sports_esports', 'icon': Icons.sports_esports},
      {'name': 'spa', 'icon': Icons.spa},
      {'name': 'attach_money', 'icon': Icons.attach_money},
      {'name': 'event', 'icon': Icons.event},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Yan Hak Düzenle' : 'Yeni Yan Hak Ekle'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Yan Hak Adı *'),
                  ),
                  const SizedBox(height: 16),
                  const Text('İkon Seçin:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: iconOptions.map((opt) {
                      final isSelected = selectedIcon == opt['name'];
                      return InkWell(
                        onTap: () => setDialogState(() => selectedIcon = opt['name'] as String),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
                          ),
                          child: Icon(opt['icon'] as IconData, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 22),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: sortOrderController,
                    decoration: const InputDecoration(labelText: 'Sıra'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Aktif'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                    contentPadding: EdgeInsets.zero,
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
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Yan hak adı zorunludur')),
                  );
                  return;
                }

                final data = {
                  'name': nameController.text,
                  'icon': selectedIcon,
                  'sort_order': int.tryParse(sortOrderController.text) ?? 0,
                  'is_active': isActive,
                };

                final service = ref.read(jobListingsAdminServiceProvider);
                try {
                  if (isEdit) {
                    await service.updateBenefit(benefit.id, data);
                  } else {
                    await service.createBenefit(data);
                  }
                  ref.invalidate(jobBenefitsProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteBenefit(JobBenefit benefit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yan Hak Sil'),
        content: Text('"${benefit.name}" yan hakkını silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(jobListingsAdminServiceProvider);
      try {
        await service.deleteBenefit(benefit.id);
        ref.invalidate(jobBenefitsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yan hak silindi'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}
