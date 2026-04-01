import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/log_service.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:intl/date_symbol_data_local.dart';

bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');

    if (_isMobile) {
      try {
        await Firebase.initializeApp();
      } catch (e, st) {
        LogService.error('Firebase init error (non-critical)', error: e, stackTrace: st, source: 'main:Firebase.initializeApp');
      }
    }

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );

    await initializeDateFormatting('tr_TR', null);

    if (_isMobile) {
      await pushNotificationService.initialize();
    }

    // Stripe initialization
    if (!kIsWeb) {
      try {
        final stripeKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
        if (stripeKey.isNotEmpty) {
          Stripe.publishableKey = stripeKey;
          await Stripe.instance.applySettings();
        }
      } catch (e, st) {
        LogService.error('Stripe init error', error: e, stackTrace: st, source: 'main:Stripe');
      }
    }

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      LogService.error(details.exceptionAsString(),
          error: details.exception,
          stackTrace: details.stack,
          source: 'FlutterError');
    };

    LogService.info('Taxi app started', source: 'main');
    runApp(const ProviderScope(child: TaxiApp()));
  }, (error, stackTrace) {
    LogService.error(error.toString(),
        error: error, stackTrace: stackTrace, source: 'ZoneError');
  });
}

class TaxiApp extends ConsumerWidget {
  const TaxiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SuperCyp Taksi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
