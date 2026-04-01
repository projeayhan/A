import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'log_service.dart';

class PaymentResult {
  final bool success;
  final String? paymentReference;
  final String? errorMessage;

  const PaymentResult({required this.success, this.paymentReference, this.errorMessage});
  const PaymentResult.ok([this.paymentReference]) : success = true, errorMessage = null;
  const PaymentResult.failed([this.errorMessage]) : success = false, paymentReference = null;
  const PaymentResult.cancelled() : success = false, paymentReference = null, errorMessage = 'cancelled';

  bool get isCancelled => errorMessage == 'cancelled';
}

class StripePaymentService {
  StripePaymentService._();
  static final StripePaymentService instance = StripePaymentService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<PaymentResult> processPayment({
    required double amount,
    required String description,
    String currency = 'try',
    Map<String, String>? metadata,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create-payment-intent',
        body: {
          'amount': amount,
          'currency': currency,
          'description': description,
          if (metadata != null) 'metadata': metadata,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      final clientSecret = (data?['clientSecret'] ?? data?['client_secret']) as String?;
      final paymentIntentId = data?['paymentIntentId'] as String?;

      if (clientSecret == null) {
        return PaymentResult.failed(data?['error']?.toString() ?? 'PaymentIntent oluşturulamadı');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'SuperCyp',
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return PaymentResult.ok(paymentIntentId);
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return const PaymentResult.cancelled();
      }
      final msg = e.error.localizedMessage ?? e.error.message;
      LogService.error('Stripe hatası: $msg', error: e, source: 'payment_service');
      return PaymentResult.failed(msg);
    } catch (e, st) {
      LogService.error('Ödeme hatası', error: e, stackTrace: st, source: 'payment_service');
      return PaymentResult.failed(e.toString());
    }
  }
}
