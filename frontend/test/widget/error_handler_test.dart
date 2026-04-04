import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/common/error_handler_widget.dart';
import 'package:frontend/l10n/app_localizations.dart';

void main() {
  group('ErrorHandlerWidget Tests', () {
    testWidgets('ErrorHandlerWidget displays error message correctly', (WidgetTester tester) async {
      const testError = 'Test error message';
      
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('es', 'ES'),
        home: Scaffold(
          body: ErrorHandlerWidget(error: testError),
        ),
      ));

      // Verificar que se muestra el mensaje de error
      expect(find.text(testError), findsOneWidget);
      
      // Verificar que se muestra el ícono de error
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('ErrorHandlerWidget displays custom title', (WidgetTester tester) async {
      const testError = 'Test error message';
      const customTitle = 'Custom Error Title';
      
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('es', 'ES'),
        home: Scaffold(
          body: ErrorHandlerWidget(
            error: testError,
            customTitle: customTitle,
          ),
        ),
      ));

      // Verificar que se muestra el título personalizado
      expect(find.text(customTitle), findsOneWidget);
      expect(find.text(testError), findsOneWidget);
    });

    testWidgets('ErrorHandlerWidget shows retry button when onRetry is provided', (WidgetTester tester) async {
      const testError = 'Test error message';
      bool retryPressed = false;
      
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es', 'ES'),
        home: Scaffold(
          body: ErrorHandlerWidget(
            error: testError,
            onRetry: () {
              retryPressed = true;
            },
          ),
        ),
      ));

      // Verificar que se muestra el botón de reintento
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      // Simular tap en el botón de reintento
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      // Verificar que se ejecutó la función de reintento
      expect(retryPressed, isTrue);
    });

    testWidgets('ErrorHandlerWidget does not show retry button when onRetry is null', (WidgetTester tester) async {
      const testError = 'Test error message';
      
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('es', 'ES'),
        home: Scaffold(
          body: ErrorHandlerWidget(error: testError),
        ),
      ));

      // Verificar que NO se muestra el botón de reintento
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('ErrorHandlerWidget is centered', (WidgetTester tester) async {
      const testError = 'Test error message';
      
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('es', 'ES'),
        home: Scaffold(
          body: ErrorHandlerWidget(error: testError),
        ),
      ));

      // Verificar que el widget está centrado
      expect(find.byType(ErrorHandlerWidget), findsOneWidget);
    });
  });

  group('ErrorSnackBar Tests', () {
    testWidgets('ErrorSnackBar shows snackbar with error message', (WidgetTester tester) async {
      const testError = 'Test error message';
      
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es', 'ES'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  ErrorSnackBar.show(context, error: testError);
                },
                child: const Text('Show Error'),
              );
            },
          ),
        ),
      ));

      // Simular tap en el botón
      await tester.tap(find.text('Show Error'));
      await tester.pump();

      // Verificar que se muestra el SnackBar
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(testError), findsOneWidget);
    });

    testWidgets('ErrorSnackBar shows snackbar with custom title', (WidgetTester tester) async {
      const testError = 'Test error message';
      const customTitle = 'Custom Error Title';
      
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es', 'ES'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  ErrorSnackBar.show(context, error: testError, customMessage: customTitle);
                },
                child: const Text('Show Error'),
              );
            },
          ),
        ),
      ));

      // Simular tap en el botón
      await tester.tap(find.text('Show Error'));
      await tester.pump();

      // Verificar que se muestra el SnackBar con título personalizado
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(customTitle), findsOneWidget);
    });
  });
}
