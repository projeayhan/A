import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract payment gateway interface.
/// Swap [MockPaymentGateway] for a real provider (Stripe, Iyzico, etc.)
/// without touching any call-sites.
abstract class PaymentGateway {
  /// Charge a customer and return a payment reference ID.
  Future<String> charge({
    required double amount,
    required String currency,
    required String description,
    Map<String, dynamic>? metadata,
  });

  /// Refund a previous charge (full or partial).
  Future<bool> refund(String paymentReference, {double? amount});

  /// Query the current status of a payment.
  /// Returns one of: 'pending' | 'completed' | 'failed' | 'refunded'
  Future<String> checkStatus(String paymentReference);
}

// ==================== MOCK IMPLEMENTATION ====================

/// Placeholder implementation – simulates success without any real API call.
/// Replace with [StripeGateway] / [IyzicoGateway] when the provider is chosen.
class MockPaymentGateway implements PaymentGateway {
  @override
  Future<String> charge({
    required double amount,
    required String currency,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    // Simulate a tiny network delay
    await Future.delayed(const Duration(milliseconds: 300));
    // Return a fake reference ID
    return 'mock_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<bool> refund(String paymentReference, {double? amount}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  @override
  Future<String> checkStatus(String paymentReference) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return 'completed';
  }
}

// ==================== STRIPE IMPLEMENTATION ====================

/// Gerçek Stripe implementasyonu — admin panel server-side (service_role) üzerinden çalışır.
/// Admin panel'de flutter_stripe kullanılmaz; ödeme işlemleri Edge Function aracılığıyla yapılır.
class StripeGateway implements PaymentGateway {
  @override
  Future<String> charge({
    required double amount,
    required String currency,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    // Admin panel'den doğrudan ödeme alınmaz.
    // Bu metod, admin'in merchant adına ödeme başlatması gerekirse kullanılır.
    // Şimdilik mock davranış — gerçek ihtiyaç olduğunda Edge Function'a bağlanır.
    throw UnimplementedError(
      'Admin panel üzerinden doğrudan ödeme alma henüz aktif değil. '
      'Ödeme akışı müşteri panellerinden (super_app, merchant_panel vb.) başlatılır.',
    );
  }

  @override
  Future<bool> refund(String paymentReference, {double? amount}) async {
    // TODO: Stripe refund API — admin panel'den iade işlemi
    // final stripe = Stripe(secretKey);
    // await stripe.refunds.create({ payment_intent: paymentReference, amount: amountCents });
    throw UnimplementedError('Stripe iade henüz implemente edilmedi');
  }

  @override
  Future<String> checkStatus(String paymentReference) async {
    // TODO: Stripe PaymentIntent status sorgusu
    throw UnimplementedError('Stripe durum sorgusu henüz implemente edilmedi');
  }
}

// ==================== RIVERPOD PROVIDER ====================

/// Aktif ödeme sağlayıcısı.
/// ────────────────────────────────────────────────
/// SAĞLAYICI DEĞİŞTİRMEK İÇİN SADECE BURAYI GÜNCELLE:
///   return StripeGateway();
///   return IyzicoGateway();
/// ────────────────────────────────────────────────
final paymentGatewayProvider = Provider<PaymentGateway>((ref) {
  return MockPaymentGateway();
});
