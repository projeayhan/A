import '../../../core/services/supabase_service.dart';
import '../../../core/services/invoice_service.dart';

// ==================== MODELS ====================

class PromotionCharge {
  final String merchantId;
  final String merchantName;
  final String listingTitle;
  final String promotionType;
  final int durationDays;
  final double amount;

  PromotionCharge({
    required this.merchantId,
    required this.merchantName,
    required this.listingTitle,
    required this.promotionType,
    required this.durationDays,
    required this.amount,
  });

  factory PromotionCharge.fromJson(Map<String, dynamic> json) {
    return PromotionCharge(
      merchantId: json['merchant_id'] as String? ?? '',
      merchantName: json['merchant_name'] as String? ?? '',
      listingTitle: json['listing_title'] as String? ?? '',
      promotionType: json['promotion_type'] as String? ?? 'featured',
      durationDays: json['duration_days'] as int? ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  String get description =>
      'Öne Çıkarma - $listingTitle (${promotionType == 'premium' ? 'Premium' : 'Öne Çıkar'}, $durationDays gün)';
}

class OrderDetail {
  final String orderNumber;
  final DateTime createdAt;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final double commissionRate;
  final double commissionAmount;

  OrderDetail({
    required this.orderNumber,
    required this.createdAt,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.commissionRate,
    required this.commissionAmount,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    return OrderDetail(
      orderNumber: json['order_number'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['payment_method'] as String? ?? '',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0,
    );
  }

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'online': case 'stripe': case 'credit_card_online': return 'Online ✓';
      case 'credit_card_on_delivery': return 'Kapıda Kart';
      case 'cash': return 'Nakit';
      default: return paymentMethod;
    }
  }

  bool get isOnline => ['online', 'stripe', 'credit_card_online'].contains(paymentMethod);
}

class CompanyBankInfo {
  final String bankName;
  final String iban;
  final String bankBranch;

  CompanyBankInfo({this.bankName = '', this.iban = '', this.bankBranch = ''});

  factory CompanyBankInfo.fromJson(Map<String, dynamic> json) {
    return CompanyBankInfo(
      bankName: json['bank_name'] as String? ?? '',
      iban: json['iban'] as String? ?? '',
      bankBranch: json['bank_branch'] as String? ?? '',
    );
  }
}

class BatchInvoicePreview {
  final String merchantId;
  final String merchantName;
  final double subtotal; // Komisyon hizmet bedeli
  final double kdvAmount; // Platform KDV
  final double total; // Komisyon + KDV (fatura tutarı)
  final int orderCount;
  final String sector;
  final List<PromotionCharge> promotionCharges;
  final double onlineTotal; // Platform tarafından tahsil edilen
  final double cashTotal; // İşletme tarafından tahsil edilen
  final double onlineCommission; // Online komisyon (zaten tahsil edildi)
  final int onlineOrderCount;
  final int cashOrderCount;
  final double netTransfer; // Online - Fatura = İşletmeye havale (+) veya borç (-)
  final double totalOrderAmount; // Toplam sipariş cirosu

  double get promotionTotal =>
      promotionCharges.fold(0, (sum, c) => sum + c.amount);

  /// Pozitif: biz işletmeye göndereceğiz
  /// Negatif: işletme bize ödeyecek
  double get finalNetTransfer => netTransfer - promotionTotal;

  BatchInvoicePreview({
    required this.merchantId,
    required this.merchantName,
    required this.subtotal,
    required this.kdvAmount,
    required this.total,
    required this.orderCount,
    required this.sector,
    this.promotionCharges = const [],
    this.onlineTotal = 0,
    this.cashTotal = 0,
    this.onlineCommission = 0,
    this.onlineOrderCount = 0,
    this.cashOrderCount = 0,
    this.netTransfer = 0,
    this.totalOrderAmount = 0,
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
      onlineTotal: (json['online_total'] as num?)?.toDouble() ?? 0,
      cashTotal: (json['cash_total'] as num?)?.toDouble() ?? 0,
      onlineCommission: (json['online_commission'] as num?)?.toDouble() ?? 0,
      onlineOrderCount: (json['online_order_count'] as int?) ?? 0,
      cashOrderCount: (json['cash_order_count'] as int?) ?? 0,
      netTransfer: (json['net_transfer'] as num?)?.toDouble() ?? 0,
      totalOrderAmount: (json['total_order_amount'] as num?)?.toDouble() ?? 0,
    );
  }

  BatchInvoicePreview withPromotionCharges(List<PromotionCharge> charges) {
    return BatchInvoicePreview(
      merchantId: merchantId,
      merchantName: merchantName,
      subtotal: subtotal,
      kdvAmount: kdvAmount,
      total: total,
      orderCount: orderCount,
      sector: sector,
      promotionCharges: charges,
      onlineTotal: onlineTotal,
      cashTotal: cashTotal,
      onlineCommission: onlineCommission,
      onlineOrderCount: onlineOrderCount,
      cashOrderCount: cashOrderCount,
      netTransfer: netTransfer,
      totalOrderAmount: totalOrderAmount,
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
  static Future<List<OrderDetail>> getOrderDetails({
    required String sector,
    required String merchantId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final result = await SupabaseService.client.rpc('get_batch_invoice_order_details', params: {
      'p_sector': sector,
      'p_merchant_id': merchantId,
      'p_start_date': startDate.toIso8601String(),
      'p_end_date': endDate.toIso8601String(),
    });
    if (result == null) return [];
    return (result as List).map((e) => OrderDetail.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<CompanyBankInfo> getBankInfo() async {
    final result = await SupabaseService.client
        .from('company_settings')
        .select('bank_name, iban, bank_branch')
        .limit(1)
        .maybeSingle();
    if (result == null) return CompanyBankInfo();
    return CompanyBankInfo.fromJson(result);
  }

  static Future<Map<String, String>> getMerchantInfo(String merchantId) async {
    final result = await SupabaseService.client
        .from('merchants')
        .select('business_name, phone, email, address, tax_number, tax_office')
        .eq('id', merchantId)
        .maybeSingle();
    return result != null ? Map<String, String>.from(result.map((k, v) => MapEntry(k, v?.toString() ?? ''))) : {};
  }

  static Future<List<BatchInvoicePreview>> getPreview({
    required String sector,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // 1. Get commission previews
    final result = await SupabaseService.client.rpc('get_batch_invoice_preview', params: {
      'p_sector': sector,
      'p_start_date': startDate.toIso8601String(),
      'p_end_date': endDate.toIso8601String(),
    });
    if (result == null) return [];

    final previews = (result as List)
        .map((e) => BatchInvoicePreview.fromJson(e as Map<String, dynamic>))
        .toList();

    // 2. Get promotion charges for the same period (only for relevant sectors)
    if (sector == 'carSales' || sector == 'realEstate' || sector == 'jobs') {
      try {
        final promoResult = await SupabaseService.client.rpc(
          'get_promotion_charges_for_invoice',
          params: {
            'p_sector': sector,
            'p_start_date': startDate.toIso8601String(),
            'p_end_date': endDate.toIso8601String(),
          },
        );

        if (promoResult != null) {
          final allCharges = (promoResult as List)
              .map((e) => PromotionCharge.fromJson(e as Map<String, dynamic>))
              .toList();

          // Group charges by merchant_id
          final Map<String, List<PromotionCharge>> byMerchant = {};
          for (final charge in allCharges) {
            byMerchant.putIfAbsent(charge.merchantId, () => []).add(charge);
          }

          // Merge charges into existing previews
          return previews.map((preview) {
            final charges = byMerchant[preview.merchantId] ?? [];
            return preview.withPromotionCharges(charges);
          }).toList();
        }
      } catch (_) {
        // Promotion charges are optional — return base previews on error
      }
    }

    return previews;
  }

  static Future<BatchInvoiceResult> createBatchInvoices({
    required List<BatchInvoicePreview> previews,
    required double kdvRate,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    int created = 0;
    int failed = 0;
    final errors = <String>[];

    for (final preview in previews) {
      try {
        // Sipariş detaylarını çek
        final orderDetails = await getOrderDetails(
          sector: preview.sector,
          merchantId: preview.merchantId,
          startDate: startDate,
          endDate: endDate,
        );

        // İşletme bilgilerini çek
        final merchantInfo = await getMerchantInfo(preview.merchantId);

        // Tüm siparişlerin komisyonu (online + nakit)
        final allCommission = orderDetails.fold<double>(0, (s, o) => s + o.commissionAmount);
        final promotionSubtotal = preview.promotionTotal;
        final totalSubtotal = allCommission + promotionSubtotal;
        final totalKdv = totalSubtotal * kdvRate;
        final totalAmount = totalSubtotal + totalKdv;
        // Sipariş satırları — her sipariş ayrı satır
        final items = <Map<String, dynamic>>[
          ...orderDetails.map((o) => {
            'description': '${o.orderNumber} (${o.paymentMethodLabel})',
            'date': o.createdAt.toIso8601String(),
            'order_amount': o.totalAmount,
            'commission': o.commissionAmount,
            'payment_method': o.paymentMethod,
            'is_online': o.isOnline,
          }),
          // Promosyon ücretleri
          ...preview.promotionCharges.map((charge) => {
            'description': charge.description,
            'quantity': 1,
            'unit_price': charge.amount,
            'commission': charge.amount,
            'is_online': false,
          }),
        ];

        final periodStr = '${_formatDate(startDate)} - ${_formatDate(endDate)}';

        // Net: online tahsilattan fatura tutarı düşülür (nakit komisyon dahil)
        final onlineOrderTotal = orderDetails.where((o) => o.isOnline).fold<double>(0, (s, o) => s + o.totalAmount);
        final netToMerchant = onlineOrderTotal - totalAmount;

        await InvoiceService.saveInvoice(
          sourceType: preview.sector,
          sourceId: preview.merchantId,
          buyerName: preview.merchantName,
          buyerTaxNumber: merchantInfo['tax_number'],
          buyerTaxOffice: merchantInfo['tax_office'],
          buyerAddress: merchantInfo['address'],
          buyerPhone: merchantInfo['phone'],
          buyerEmail: merchantInfo['email'],
          subtotal: totalSubtotal,
          kdvRate: kdvRate,
          kdvAmount: totalKdv,
          total: totalAmount,
          items: items,
          invoiceType: 'batch_commission',
          invoicePeriod: periodStr,
          onlineTotal: preview.onlineTotal,
          cashTotal: preview.cashTotal,
          netTransfer: netToMerchant,
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

  static String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

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
      case 'carSales':
        return 'Araç Satış';
      case 'realEstate':
        return 'Emlak';
      case 'jobs':
        return 'İş İlanları';
      default:
        return sector;
    }
  }
}
