import 'package:flutter_riverpod/flutter_riverpod.dart';

// Current tab provider - tüm uygulama genelinde bottom navigation state'i
final currentTabProvider = StateProvider<int>((ref) => 0);
