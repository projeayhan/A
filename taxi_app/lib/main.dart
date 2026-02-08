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

import 'package:intl/date_symbol_data_local.dart';

bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Firebase (only on mobile)
  if (_isMobile) {
    await Firebase.initializeApp();
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Initialize date formatting
  await initializeDateFormatting('tr_TR', null);

  // Initialize push notifications (only on mobile)
  if (_isMobile) {
    await pushNotificationService.initialize();
  }

  runApp(const ProviderScope(child: TaxiApp()));
}

class TaxiApp extends ConsumerWidget {
  const TaxiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Taxi App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
