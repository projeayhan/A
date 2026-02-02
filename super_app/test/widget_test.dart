import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Widget Performance Tests', () {

    // 1. ListView Performans Testi
    testWidgets('ListView should render efficiently', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: 1000,
              itemBuilder: (context, index) => ListTile(
                title: Text('Item $index'),
              ),
            ),
          ),
        ),
      );

      // İlk render başarılı
      expect(find.byType(ListView), findsOneWidget);

      // Scroll performansı
      await tester.fling(find.byType(ListView), const Offset(0, -500), 1000);
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsWidgets);
    });

    // 2. Const Widget Optimizasyonu Testi
    testWidgets('Const widgets should not rebuild unnecessarily', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    // Bu widget her setState'de rebuild olmamalı
                    const Text('Const Widget'),
                    Builder(
                      builder: (context) {
                        buildCount++;
                        return Text('Build count: $buildCount');
                      },
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Rebuild'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      expect(buildCount, equals(1));

      // Butona tıkla - setState çağır
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Sadece non-const widget rebuild olmalı
      expect(buildCount, equals(2));
    });

    // 3. Image Widget Testi
    testWidgets('Image widget should handle errors gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Image.network(
              'https://example.com/image.jpg',
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.error);
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const CircularProgressIndicator();
              },
            ),
          ),
        ),
      );

      // Widget oluşturuldu
      expect(find.byType(Image), findsOneWidget);
    });

    // 4. Form Validation Performansı
    testWidgets('Form validation should be fast', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                  ElevatedButton(
                    onPressed: () => formKey.currentState?.validate(),
                    child: const Text('Validate'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final stopwatch = Stopwatch()..start();

      // 100 kez validate çağır
      for (int i = 0; i < 100; i++) {
        formKey.currentState?.validate();
      }

      stopwatch.stop();

      // 100ms'den az sürmeli
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    // 5. Animation Controller Dispose Testi
    testWidgets('AnimationController should be disposed properly', (tester) async {
      bool isDisposed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: _AnimatedWidget(
            onDispose: () => isDisposed = true,
          ),
        ),
      );

      expect(isDisposed, isFalse);

      // Widget'ı kaldır
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      expect(isDisposed, isTrue);
    });

  });
}

// Test için yardımcı widget
class _AnimatedWidget extends StatefulWidget {
  final VoidCallback onDispose;

  const _AnimatedWidget({required this.onDispose});

  @override
  State<_AnimatedWidget> createState() => _AnimatedWidgetState();
}

class _AnimatedWidgetState extends State<_AnimatedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('Animated'));
  }
}
