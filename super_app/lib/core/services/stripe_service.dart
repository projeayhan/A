// ╔══════════════════════════════════════════════════════════════════╗
// ║  DEPRECATED — Bu dosya geriye uyumluluk için korunmaktadır.    ║
// ║  Yeni kod payment_service.dart kullanmalıdır.                  ║
// ║  import 'package:super_app/core/services/payment_service.dart' ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'payment_service.dart';
export 'payment_service.dart' show PaymentResult;

/// Eski StripeService wrapper — yeni PaymentService'e delege eder.
/// Mevcut call-site'lar kırılmasın diye korunuyor.
class StripeService {
  static final StripeService _instance = StripeService._internal();
  static StripeService get instance => _instance;
  factory StripeService() => _instance;
  StripeService._internal();

  Future<PaymentResult> processPayment({
    required double amount,
    required String description,
    Map<String, String>? metadata,
  }) async {
    return activePaymentService.processPayment(
      amount: amount,
      description: description,
      metadata: metadata,
    );
  }
}
