import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:super_app/core/services/log_service.dart';

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

/// Soyut ödeme servisi.
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

/// Stripe ödeme implementasyonu.
/// Mobil: PaymentIntent + Payment Sheet
/// Web: Checkout Session + redirect
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
    if (kIsWeb) {
      return _processPaymentWeb(
        amount: amount,
        description: description,
        currency: currency,
        metadata: metadata,
      );
    }
    return _processPaymentMobile(
      amount: amount,
      description: description,
      currency: currency,
      metadata: metadata,
    );
  }

  /// Web: Stripe Checkout Session → redirect
  Future<PaymentResult> _processPaymentWeb({
    required double amount,
    required String description,
    String currency = 'try',
    Map<String, String>? metadata,
  }) async {
    try {
      final orderId = metadata?['order_id'] ?? '';

      final response = await _client.functions.invoke(
        'create-payment-intent',
        body: {
          'amount': amount,
          'currency': currency,
          'description': description,
          'mode': 'checkout',
          if (metadata != null) 'metadata': metadata,
          'success_url': '${Uri.base.origin}/#/food/order-success/$orderId?payment=success',
          'cancel_url': '${Uri.base.origin}/#/food/cart?payment=cancelled',
        },
      );

      final data = response.data as Map<String, dynamic>?;
      final checkoutUrl = data?['url'] as String?;

      if (checkoutUrl == null) {
        return PaymentResult.failed(
          data?['error']?.toString() ?? 'Checkout oturumu oluşturulamadı',
        );
      }

      // Stripe Checkout sayfasına yönlendir
      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, webOnlyWindowName: '_self');
      }

      // Redirect olduğu için bu satıra genelde dönmez
      return const PaymentResult.ok('checkout_redirect');
    } catch (e, st) {
      LogService.error('Web ödeme hatası', error: e, stackTrace: st, source: 'StripePaymentService:_processPaymentWeb');
      return PaymentResult.failed(e.toString());
    }
  }

  /// Mobil: PaymentIntent + Payment Sheet
  Future<PaymentResult> _processPaymentMobile({
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

      // Stripe Payment Sheet aç
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'SuperCyp',
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return const PaymentResult.ok();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return const PaymentResult.cancelled();
      }
      final msg = e.error.localizedMessage ?? e.error.message;
      LogService.error('Stripe hatası', error: e, source: 'StripePaymentService:_processPaymentMobile');
      return PaymentResult.failed(msg);
    } catch (e, st) {
      LogService.error('Ödeme hatası', error: e, stackTrace: st, source: 'StripePaymentService:_processPaymentMobile');
      return PaymentResult.failed(e.toString());
    }
  }
}

// ===================== FACTORY =====================

PaymentService get activePaymentService => StripePaymentService.instance;
