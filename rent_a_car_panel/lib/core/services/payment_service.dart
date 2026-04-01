import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rent_a_car_panel/core/services/log_service.dart';

/// Ödeme sonucu — tüm sağlayıcılar için ortak.
class PaymentResult {
  final bool success;
  final String? paymentReference;
  final String? errorMessage;

  const PaymentResult({
    required this.success,
    this.paymentReference,
    this.errorMessage,
  });

  const PaymentResult.ok([this.paymentReference])
      : success = true,
        errorMessage = null;

  const PaymentResult.failed([this.errorMessage])
      : success = false,
        paymentReference = null;

  const PaymentResult.cancelled()
      : success = false,
        paymentReference = null,
        errorMessage = 'cancelled';

  bool get isCancelled => errorMessage == 'cancelled';
}

/// Soyut ödeme servisi — sağlayıcı bağımsız interface.
abstract class PaymentService {
  Future<PaymentResult> processPayment({
    required double amount,
    required String description,
    String currency = 'try',
    Map<String, String>? metadata,
  });

  String get providerName;
}

// ===================== STRIPE IMPLEMENTATION =====================

class StripePaymentService extends PaymentService {
  StripePaymentService._();
  static final StripePaymentService _instance = StripePaymentService._();
  static StripePaymentService get instance => _instance;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  String get providerName => 'Stripe';

  @override
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

      if (clientSecret == null) {
        return PaymentResult.failed(
          data?['error']?.toString() ?? 'PaymentIntent oluşturulamadı',
        );
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'SuperCyp',
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return const PaymentResult.ok();
    } on StripeException catch (e, st) {
      if (e.error.code == FailureCode.Canceled) {
        return const PaymentResult.cancelled();
      }
      final msg = e.error.localizedMessage ?? e.error.message;
      LogService.error('Stripe hatası', error: e, stackTrace: st, source: 'StripePaymentService:processPayment');
      return PaymentResult.failed(msg);
    } catch (e, st) {
      LogService.error('Ödeme hatası', error: e, stackTrace: st, source: 'StripePaymentService:processPayment');
      return PaymentResult.failed(e.toString());
    }
  }
}

/// Aktif ödeme servisini döner.
/// SAĞLAYICI DEĞİŞTİRMEK İÇİN SADECE BURAYI GÜNCELLE.
PaymentService get activePaymentService => StripePaymentService.instance;
