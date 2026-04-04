import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/main.dart' as app;

// NOTA: Para que esta prueba funcione, se debe configurar un entorno de prueba
// de Supabase con credenciales válidas y un usuario de prueba.
// Las credenciales deben pasarse como variables de entorno al ejecutar la prueba.
//
// Para ejecutar este test:
// flutter test integration_test/app_integration_test.dart
// O desde el directorio frontend:
// flutter test test/integration/app_integration_test.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Pruebas de Integración de la Aplicación', () {
    testWidgets('Flujo de Login y Logout Exitoso', (tester) async {
      // 1. Inicializar la aplicación
      app.main();
      await tester.pumpAndSettle();

      // 2. Verificar que estamos en la pantalla de Login
      expect(find.text('Iniciar Sesión'), findsOneWidget);

      // 3. Introducir credenciales de prueba (deben ser válidas en Supabase)
      // NOTA: Usar variables de entorno o valores por defecto
      // Configurar con: --dart-define=TEST_USER_EMAIL=... --dart-define=TEST_USER_PASSWORD=...
      const testEmail = String.fromEnvironment(
        'TEST_USER_EMAIL',
        defaultValue: 'test@example.com',
      );
      const testPassword = String.fromEnvironment(
        'TEST_USER_PASSWORD',
        defaultValue: 'password',
      );

      // Encontrar los campos de texto
      final emailField = find.byKey(const Key('loginEmailField'));
      final passwordField = find.byKey(const Key('loginPasswordField'));
      final loginButton = find.byKey(const Key('loginButton'));

      // Verificar que los campos existen
      expect(emailField, findsOneWidget);
      expect(passwordField, findsOneWidget);
      expect(loginButton, findsOneWidget);

      // Escribir en los campos
      await tester.enterText(emailField, testEmail);
      await tester.enterText(passwordField, testPassword);
      await tester.pumpAndSettle();

      // 4. Presionar el botón de Login
      await tester.tap(loginButton);
      await tester.pumpAndSettle(
        const Duration(seconds: 3),
      ); // Esperar la respuesta de Supabase

      // 5. Verificar navegación al Dashboard (asumiendo que el dashboard de estudiante tiene un texto específico)
      // NOTA: Reemplazar con un texto específico del dashboard de destino
      expect(find.text('Bienvenido, Test User'), findsOneWidget);

      // 6. Realizar Logout
      // Asumimos que hay un botón de logout accesible en el dashboard
      final logoutButton = find.byKey(const Key('logoutButton'));
      expect(logoutButton, findsOneWidget);

      await tester.tap(logoutButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 7. Verificar que volvemos a la pantalla de Login
      expect(find.text('Iniciar Sesión'), findsOneWidget);
    });

    testWidgets('Flujo de Login Fallido', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      final emailField = find.byKey(const Key('loginEmailField'));
      final passwordField = find.byKey(const Key('loginPasswordField'));
      final loginButton = find.byKey(const Key('loginButton'));

      // Usar credenciales inválidas
      await tester.enterText(emailField, 'invalid@example.com');
      await tester.enterText(passwordField, 'wrongpassword');
      await tester.pumpAndSettle();

      await tester.tap(loginButton);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verificar que aparece un mensaje de error (SnackBar o texto en pantalla)
      // NOTA: Reemplazar con el texto real del mensaje de error de tu app
      expect(find.textContaining('Credenciales inválidas'), findsOneWidget);

      // Verificar que seguimos en la pantalla de Login
      expect(find.text('Iniciar Sesión'), findsOneWidget);
    });
  });
}
