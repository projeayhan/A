import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/supabase_service.dart';
import 'core/services/notification_sound_service.dart';
import 'core/services/log_service.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');
    await SupabaseService.initialize();
    await notificationSoundService.initialize();
    await initializeDateFormatting('tr', null);

    // Stripe initialization
    if (!kIsWeb) {
      try {
        final stripeKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
        if (stripeKey.isNotEmpty) {
          Stripe.publishableKey = stripeKey;
          await Stripe.instance.applySettings();
        }
      } catch (e) {
        LogService.warn('Stripe init error: $e', source: 'main');
      }
    }

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      LogService.error(details.exceptionAsString(),
          error: details.exception,
          stackTrace: details.stack,
          source: 'FlutterError');
    };

    LogService.info('Merchant panel started', source: 'main');
    runApp(const ProviderScope(child: MerchantPanelApp()));
  }, (error, stackTrace) {
    LogService.error(error.toString(),
        error: error, stackTrace: stackTrace, source: 'ZoneError');
  });
}

class MerchantPanelApp extends ConsumerWidget {
  const MerchantPanelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SuperCyp İşletme',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.0),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
