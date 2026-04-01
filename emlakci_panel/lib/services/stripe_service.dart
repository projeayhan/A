// ╔══════════════════════════════════════════════════════════════════╗
// ║  DEPRECATED — Bu dosya geriye uyumluluk için korunmaktadır.    ║
// ║  Yeni kod payment_service.dart kullanmalıdır.                  ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'payment_service.dart';

/// Eski StripeService wrapper — yeni PaymentService'e delege eder.
class StripeService {
  static final StripeService _instance = StripeService._internal();
  static StripeService get instance => _instance;
  factory StripeService() => _instance;
  StripeService._internal();

  Future<bool> processPayment({
    required double amount,
    required String description,
    Map<String, String>? metadata,
  }) async {
    final result = await activePaymentService.processPayment(
      amount: amount,
      description: description,
      metadata: metadata,
    );
    return result.success;
  }
}
