import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/supabase_service.dart';
import 'core/services/log_service.dart';
import 'core/providers/theme_provider.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: '.env');
    await SupabaseService.initialize();
    await initializeDateFormatting('tr_TR', null);

    FlutterError.onError = (details) {
      // Known Riverpod + GoRouter ShellRoute issue in debug mode
      final msg = details.exception.toString();
      if (msg.contains('_dependents.isEmpty') ||
          msg.contains('_dependents!.isEmpty')) {
        debugPrint('Suppressed known _dependents.isEmpty assertion');
        return;
      }
      FlutterError.presentError(details);
      LogService.error(details.exceptionAsString(),
          error: details.exception,
          stackTrace: details.stack,
          source: 'FlutterError');
    };

    LogService.info('Admin panel started', source: 'main');
    runApp(const ProviderScope(child: AdminPanelApp()));
  }, (error, stackTrace) {
    LogService.error(error.toString(),
        error: error, stackTrace: stackTrace, source: 'ZoneError');
  });
}

class AdminPanelApp extends ConsumerWidget {
  const AdminPanelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'SuperCyp Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
