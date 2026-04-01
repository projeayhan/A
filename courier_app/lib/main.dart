import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/notification_sound_service.dart';
import 'core/services/log_service.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');

    if (!kIsWeb) {
      try {
        await Firebase.initializeApp();
      } catch (e, st) {
        LogService.error('Firebase init error', error: e, stackTrace: st, source: 'main:Firebase.initializeApp');
      }
    }

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );

    await initializeDateFormatting('tr', null);
    await notificationSoundService.initialize();

    if (!kIsWeb) {
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

    LogService.info('Courier app started', source: 'main');
    runApp(const ProviderScope(child: CourierApp()));
  }, (error, stackTrace) {
    LogService.error(error.toString(),
        error: error, stackTrace: stackTrace, source: 'ZoneError');
  });
}

class CourierApp extends ConsumerWidget {
  const CourierApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SuperCyp Kurye',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
