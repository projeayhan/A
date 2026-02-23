import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/supabase_service.dart';
import 'core/services/security_service.dart';
import 'core/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await initializeDateFormatting('tr_TR', null);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _logError(details.exception.toString(), details.stack?.toString());
  };

  runZonedGuarded(() {
    runApp(const ProviderScope(child: AdminPanelApp()));
  }, (error, stackTrace) {
    _logError(error.toString(), stackTrace.toString());
  });
}

void _logError(String message, String? stack) {
  try {
    SecurityService(Supabase.instance.client).logSystemError(
      errorType: 'flutter_error',
      errorMessage: message.length > 500 ? message.substring(0, 500) : message,
      stackTrace: stack?.length != null && stack!.length > 1000
          ? stack.substring(0, 1000)
          : stack,
      severity: 'error',
    );
  } catch (_) {
    // Silent - don't let error logging break the app
  }
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
    );
  }
}
