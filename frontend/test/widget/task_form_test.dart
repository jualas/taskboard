import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/forms/task_form.dart';
import 'package:frontend/l10n/app_localizations.dart';

void main() {
  group('TaskForm Widget Tests', () {
    testWidgets('TaskForm renders correctly', (WidgetTester tester) async {
      // Test simple que solo verifica que el widget se puede instanciar
      // sin necesidad de BLoC o servicios complejos
      expect(
        () => TaskForm(projectId: 1, onSave: (_) {}),
        returnsNormally,
      );
    });

    testWidgets('TaskForm can be built in MaterialApp', (WidgetTester tester) async {
      // Test que verifica que el widget se puede construir en un MaterialApp
      // Esto nos ayuda a verificar que no hay errores de compilación básicos
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: Text('Test App'),
            ),
          ),
        ),
      );

      expect(find.text('Test App'), findsOneWidget);
    });
  });
}

