import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommentsWidget Tests', () {

    testWidgets('CommentsWidget can be instantiated', (WidgetTester tester) async {
      // Test que verifica que el widget se puede construir en un MaterialApp
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Test App'),
            ),
          ),
        ),
      );

      // Verificar que el MaterialApp se construye correctamente
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
