import '../../../core/services/supabase_service.dart';
import '../../../core/services/invoice_service.dart';

// ==================== MODELS ====================

class BatchInvoicePreview {
  final String merchantId;
  final String merchantName;
  final double subtotal;
  final double kdvAmount;
  final double total;
  final int orderCount;
  final String sector;

  BatchInvoicePreview({
    required this.merchantId,
    required this.merchantName,
    required this.subtotal,
    required this.kdvAmount,
    required this.total,
    required this.orderCount,
    required this.sector,
  });

  factory BatchInvoicePreview.fromJson(Map<String, dynamic> json) {
    return BatchInvoicePreview(
      merchantId: json['merchant_id'] as String? ?? '',
      merchantName: json['merchant_name'] as String? ?? '',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      kdvAmount: (json['kdv_amount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      orderCount: json['order_count'] as int? ?? 0,
      sector: json['sector'] as String? ?? '',
    );
  }
}

class BatchInvoiceResult {
  final int totalCreated;
  final int totalFailed;
  final List<String> errors;

  BatchInvoiceResult({
    required this.totalCreated,
    required this.totalFailed,
    required this.errors,
  });
}

// ==================== SERVICE ====================

class BatchInvoiceService {
  static Future<List<BatchInvoicePreview>> getPreview({
    required String sector,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final result = await SupabaseService.client.rpc('get_batch_invoice_preview', params: {
        'p_sector': sector,
        'p_start_date': startDate.toIso8601String(),
        'p_end_date': endDate.toIso8601String(),
      });
      if (result == null) return [];
      return (result as List)
          .map((e) => BatchInvoicePreview.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<BatchInvoiceResult> createBatchInvoices({
    required List<BatchInvoicePreview> previews,
    required double kdvRate,
  }) async {
    int created = 0;
    int failed = 0;
    final errors = <String>[];

    for (final preview in previews) {
      try {
        await InvoiceService.saveInvoice(
          sourceType: preview.sector,
          sourceId: preview.merchantId,
          buyerName: preview.merchantName,
          subtotal: preview.subtotal,
          kdvRate: kdvRate,
          kdvAmount: preview.kdvAmount,
          total: preview.total,
          items: [
            {
              'description': '${_sectorLabel(preview.sector)} komisyon faturası (${preview.orderCount} sipariş)',
              'quantity': 1,
              'unit_price': preview.subtotal,
              'total': preview.subtotal,
            }
          ],
          invoiceType: 'commission',
        );
        created++;
      } catch (e) {
        failed++;
        errors.add('${preview.merchantName}: $e');
      }
    }

    return BatchInvoiceResult(
      totalCreated: created,
      totalFailed: failed,
      errors: errors,
    );
  }

  static String _sectorLabel(String sector) {
    switch (sector) {
      case 'food':
        return 'Yemek';
      case 'store':
        return 'Market/Mağaza';
      case 'taxi':
        return 'Taksi';
      case 'rental':
        return 'Kiralama';
      default:
        return sector;
    }
  }
}
