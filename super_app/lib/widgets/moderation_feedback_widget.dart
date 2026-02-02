import 'package:flutter/material.dart';

/// Moderasyon durumu enum
enum ModerationStatus {
  pending,
  approved,
  rejected,
  manualReview;

  static ModerationStatus fromString(String? status) {
    switch (status) {
      case 'approved':
        return ModerationStatus.approved;
      case 'rejected':
        return ModerationStatus.rejected;
      case 'manual_review':
        return ModerationStatus.manualReview;
      default:
        return ModerationStatus.pending;
    }
  }
}

/// Moderasyon bilgisi model
class ModerationInfo {
  final ModerationStatus status;
  final int? score;
  final String? reason;
  final List<String> flags;
  final DateTime? moderatedAt;

  ModerationInfo({
    required this.status,
    this.score,
    this.reason,
    this.flags = const [],
    this.moderatedAt,
  });

  String get statusText {
    switch (status) {
      case ModerationStatus.approved:
        return 'Onaylandı';
      case ModerationStatus.rejected:
        return 'Reddedildi';
      case ModerationStatus.manualReview:
        return 'İnceleniyor';
      case ModerationStatus.pending:
        return 'Beklemede';
    }
  }

  Color get statusColor {
    switch (status) {
      case ModerationStatus.approved:
        return const Color(0xFF10B981);
      case ModerationStatus.rejected:
        return const Color(0xFFEF4444);
      case ModerationStatus.manualReview:
        return const Color(0xFFF59E0B);
      case ModerationStatus.pending:
        return const Color(0xFF6B7280);
    }
  }

  IconData get statusIcon {
    switch (status) {
      case ModerationStatus.approved:
        return Icons.check_circle_rounded;
      case ModerationStatus.rejected:
        return Icons.cancel_rounded;
      case ModerationStatus.manualReview:
        return Icons.hourglass_top_rounded;
      case ModerationStatus.pending:
        return Icons.schedule_rounded;
    }
  }
}

/// Moderasyon durumu göstergesi - küçük badge
class ModerationStatusBadge extends StatelessWidget {
  final ModerationInfo info;
  final bool showLabel;

  const ModerationStatusBadge({
    super.key,
    required this.info,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: info.statusColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: info.statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.statusIcon, size: 14, color: info.statusColor),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              info.statusText,
              style: TextStyle(
                color: info.statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Moderasyon feedback kartı - red sebebi ve düzeltme önerileri
class ModerationFeedbackCard extends StatelessWidget {
  final ModerationInfo info;
  final VoidCallback? onEditPressed;
  final bool isDark;

  const ModerationFeedbackCard({
    super.key,
    required this.info,
    this.onEditPressed,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    if (info.status == ModerationStatus.approved) {
      return _buildApprovedCard();
    }

    if (info.status == ModerationStatus.pending) {
      return _buildPendingCard();
    }

    if (info.status == ModerationStatus.manualReview) {
      return _buildManualReviewCard();
    }

    return _buildRejectedCard();
  }

  Widget _buildApprovedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İlanınız Onaylandı',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'İlanınız yayında ve kullanıcılar tarafından görüntülenebilir.',
                  style: TextStyle(
                    color: Color(0xFF065F46),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6B7280).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6B7280).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6B7280).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Color(0xFF6B7280),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İnceleme Bekliyor',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'İlanınız inceleme kuyruğunda. Kısa süre içinde sonuçlanacak.',
                  style: TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualReviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: Color(0xFFF59E0B),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manuel İnceleme',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'İlanınız ekibimiz tarafından manuel olarak inceleniyor. Bu işlem biraz zaman alabilir.',
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: Color(0xFFEF4444),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'İlanınız Reddedildi',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Lütfen aşağıdaki sorunları düzeltip tekrar gönderin.',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Red sebebi
          if (info.reason != null && info.reason!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Red Sebebi',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _translateReason(info.reason!),
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Sorunlar listesi
          if (info.flags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Düzeltilmesi Gereken Sorunlar',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...info.flags.map((flag) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _translateFlag(flag),
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],

          // Düzenle butonu
          if (onEditPressed != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onEditPressed,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('İlanı Düzenle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _translateReason(String reason) {
    // İngilizce sebepleri Türkçe'ye çevir
    return reason
        .replaceAll('unrealistic pricing', 'gerçekçi olmayan fiyatlandırma')
        .replaceAll('missing critical', 'eksik kritik')
        .replaceAll('information', 'bilgi')
        .replaceAll('property', 'mülk')
        .replaceAll('vehicle', 'araç')
        .replaceAll('job', 'iş')
        .replaceAll('listing', 'ilan')
        .replaceAll('suspiciously', 'şüpheli şekilde')
        .replaceAll('low', 'düşük')
        .replaceAll('high', 'yüksek')
        .replaceAll('price', 'fiyat')
        .replaceAll('incomplete', 'eksik')
        .replaceAll('vague', 'belirsiz')
        .replaceAll('description', 'açıklama')
        .replaceAll('contact info', 'iletişim bilgisi')
        .replaceAll('hidden', 'gizlenmeli')
        .replaceAll('phone', 'telefon')
        .replaceAll('email', 'e-posta')
        .replaceAll('misleading', 'yanıltıcı')
        .replaceAll('spam', 'spam içerik')
        .replaceAll('duplicate', 'tekrarlanan içerik')
        .replaceAll('fake', 'sahte')
        .replaceAll('fraudulent', 'dolandırıcılık şüphesi');
  }

  String _translateFlag(String flag) {
    final translations = {
      'unrealistic_pricing': 'Fiyat gerçekçi görünmüyor',
      'unrealistic pricing': 'Fiyat gerçekçi görünmüyor',
      'missing_critical_information': 'Kritik bilgiler eksik',
      'missing_critical_property_information': 'Mülk hakkında kritik bilgiler eksik',
      'missing critical information': 'Kritik bilgiler eksik',
      'incomplete': 'İlan bilgileri eksik',
      'vague': 'Açıklamalar belirsiz',
      'contact_info_visible': 'İletişim bilgileri açıklamada görünüyor (kaldırın)',
      'spam': 'Spam içerik tespit edildi',
      'duplicate': 'Tekrarlanan içerik',
      'misleading': 'Yanıltıcı bilgiler içeriyor',
      'blacklist_violation': 'Yasaklı kelime tespit edildi',
      'blacklist_flag': 'Şüpheli kelime tespit edildi',
      'fake': 'Sahte ilan şüphesi',
      'fraudulent': 'Dolandırıcılık şüphesi',
      'inappropriate': 'Uygunsuz içerik',
      'illegal_content': 'Yasadışı içerik',
      'mileage_inconsistency': 'Kilometre bilgisi tutarsız',
      'year_mileage_mismatch': 'Yıl ve kilometre uyumsuz',
    };

    return translations[flag.toLowerCase()] ??
           translations[flag] ??
           flag.replaceAll('_', ' ');
  }
}

/// Moderasyon durumu dialog'u göster
void showModerationFeedbackDialog(
  BuildContext context, {
  required ModerationInfo info,
  VoidCallback? onEditPressed,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(info.statusIcon, color: info.statusColor, size: 24),
          const SizedBox(width: 8),
          Text(
            'İlan Durumu',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: ModerationFeedbackCard(
          info: info,
          onEditPressed: onEditPressed != null
              ? () {
                  Navigator.pop(context);
                  onEditPressed();
                }
              : null,
          isDark: isDark,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    ),
  );
}
