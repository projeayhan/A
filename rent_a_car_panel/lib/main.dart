import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme.dart';
import 'core/router.dart';
import 'core/supabase_config.dart';
import 'core/services/log_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');
    await initializeDateFormatting('tr_TR', null);
    await initSupabase();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      LogService.error(details.exceptionAsString(),
          error: details.exception,
          stackTrace: details.stack,
          source: 'FlutterError');
    };

    LogService.info('Rent a car panel started', source: 'main');
    runApp(const ProviderScope(child: RentACarPanelApp()));
  }, (error, stackTrace) {
    LogService.error(error.toString(),
        error: error, stackTrace: stackTrace, source: 'ZoneError');
  });
}

class RentACarPanelApp extends ConsumerWidget {
  const RentACarPanelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SuperCyp Kiralama',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
