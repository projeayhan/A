import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/router/app_router.dart';

class SlaBreachCard extends ConsumerWidget {
  const SlaBreachCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final supabase = ref.watch(supabaseProvider);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from('support_tickets')
          .select('id, subject, priority, sla_due_at, customer_name')
          .inFilter('status', ['open', 'assigned', 'pending', 'waiting_customer'])
          .lte('sla_due_at', DateTime.now().toIso8601String())
          .order('sla_due_at')
          .limit(5),
      builder: (context, snapshot) {
        final tickets = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tickets.isNotEmpty ? AppColors.error.withValues(alpha: 0.3) : borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text('SLA Ihlalleri', style: TextStyle(color: AppColors.error, fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (tickets.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${tickets.length}', style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (tickets.isEmpty)
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text('SLA ihlali yok', style: TextStyle(color: AppColors.success, fontSize: 13)),
                  ],
                )
              else
                ...tickets.map((t) {
                  final slaDue = DateTime.tryParse(t['sla_due_at'] ?? '');
                  final overdue = slaDue != null ? DateTime.now().difference(slaDue) : Duration.zero;
                  final overdueText = overdue.inHours > 0 ? '${overdue.inHours}s ${overdue.inMinutes % 60}dk' : '${overdue.inMinutes}dk';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => context.go('${AppRoutes.tickets}/${t['id']}'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t['subject'] ?? '', style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(t['customer_name'] ?? '', style: TextStyle(color: textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            Text('+$overdueText', style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}
