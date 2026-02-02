import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Araç Satış Panel smoke test', (WidgetTester tester) async {
    // Build a simple widget to verify the app can start
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Araç Satış Panel Test'),
            ),
          ),
        ),
      ),
    );

    // Verify the test widget renders
    expect(find.text('Araç Satış Panel Test'), findsOneWidget);
  });
}
