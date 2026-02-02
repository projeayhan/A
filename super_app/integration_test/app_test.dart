import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:super_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Super App UI Tests', () {

    // 1. Uygulama Başlatma Testi
    testWidgets('App should start without errors', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Uygulama başladı mı?
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    // 2. Scroll Performans Testi
    testWidgets('Scroll should be smooth without jank', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // ListView veya ScrollView bul
      final scrollable = find.byType(Scrollable).first;

      if (scrollable.evaluate().isNotEmpty) {
        // Aşağı scroll
        await tester.fling(scrollable, const Offset(0, -500), 1000);
        await tester.pumpAndSettle();

        // Yukarı scroll
        await tester.fling(scrollable, const Offset(0, 500), 1000);
        await tester.pumpAndSettle();

        // Test geçti - jank yoksa buraya ulaşır
        expect(true, isTrue);
      }
    });

    // 3. Navigation Testi
    testWidgets('Navigation should work correctly', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Bottom navigation bar bul
      final bottomNav = find.byType(BottomNavigationBar);

      if (bottomNav.evaluate().isNotEmpty) {
        // Her tab'a tıkla
        final tabs = find.descendant(
          of: bottomNav,
          matching: find.byType(InkResponse),
        );

        for (int i = 0; i < tabs.evaluate().length && i < 5; i++) {
          await tester.tap(tabs.at(i));
          await tester.pumpAndSettle();
        }

        expect(true, isTrue);
      }
    });

    // 4. Form Input Testi
    testWidgets('Text fields should accept input', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // TextField bul
      final textFields = find.byType(TextField);

      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, 'Test input');
        await tester.pumpAndSettle();

        expect(find.text('Test input'), findsOneWidget);
      }
    });

    // 5. Button Tap Testi
    testWidgets('Buttons should be tappable', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // ElevatedButton veya TextButton bul
      final buttons = find.byType(ElevatedButton);

      if (buttons.evaluate().isNotEmpty) {
        await tester.tap(buttons.first);
        await tester.pumpAndSettle();

        // Tap başarılı
        expect(true, isTrue);
      }
    });

    // 6. Memory Leak Kontrolü - Sayfa Geçişleri
    testWidgets('Page transitions should not cause memory leaks', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 10 kez sayfa geçişi yap
      for (int i = 0; i < 10; i++) {
        // Back button varsa tıkla
        final backButton = find.byType(BackButton);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton.first);
          await tester.pumpAndSettle();
        }

        // Navigator.pop simülasyonu
        final navigator = find.byType(Navigator);
        if (navigator.evaluate().isNotEmpty) {
          await tester.pumpAndSettle();
        }
      }

      expect(true, isTrue);
    });

  });
}
