import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend/screens/auth/login_screen_bloc.dart';
import 'package:frontend/blocs/auth_bloc.dart';
import 'widget_test_utils.dart';
import 'widget_test_utils.mocks.dart';

void main() {
  group('LoginScreenBloc Widget Tests', () {
    late MockAuthService mockAuthService;
    late AuthBloc authBloc;

    setUp(() {
      mockAuthService = MockAuthService();
      authBloc = AuthBloc(authService: mockAuthService);

      // Configurar mocks básicos
      WidgetTestUtils.setupBasicMocks(
        mockAuthService: mockAuthService,
        mockAnteprojectsService: MockAnteprojectsService(),
        mockTasksService: MockTasksService(),
      );
    });

    tearDown(() {
      authBloc.close();
    });

    Widget createTestWidget() {
      return WidgetTestUtils.createTestApp(
        child: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const LoginScreenBloc(),
        ),
      );
    }

    testWidgets('LoginScreenBloc shows login form with all required elements',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Verificar que la pantalla se renderiza correctamente
      expect(
        find.byType(Scaffold),
        findsOneWidget,
        reason: 'Debe mostrar Scaffold',
      );
      expect(
        find.byType(AppBar),
        findsOneWidget,
        reason: 'Debe mostrar AppBar',
      );

      // Verificar que los campos del formulario están presentes
      expect(
        find.byType(TextField),
        findsNWidgets(2),
        reason: 'Debe mostrar 2 TextFields (Email y Password)',
      );
      expect(
        find.byType(ElevatedButton),
        findsOneWidget,
        reason: 'Debe mostrar botón de login',
      );
    });

    testWidgets('LoginScreenBloc shows loading state during login',
        (WidgetTester tester) async {
      // Configurar mock para que retorne después de un delay
      when(mockAuthService.signIn(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 200));
        return {
          'success': true,
          'user': WidgetTestUtils.createTestUser().toJson(),
        };
      });

      when(mockAuthService.createUserFromLoginResponse(any))
          .thenReturn(WidgetTestUtils.createTestUser());

      await tester.pumpWidget(createTestWidget());

      // Ingresar credenciales
      await tester.enterText(find.byType(TextField).first, 'test@jualas.es');
      await tester.enterText(find.byType(TextField).last, 'password123');

      // Presionar botón de login
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verificar que el botón está deshabilitado durante la carga
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(
        button.onPressed,
        isNull,
        reason: 'El botón debe estar deshabilitado durante la carga',
      );
    });

    testWidgets('LoginScreenBloc shows error state with invalid credentials',
        (WidgetTester tester) async {
      // Configurar mock para que lance error
      when(mockAuthService.signIn(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(Exception('Invalid credentials'));

      await tester.pumpWidget(createTestWidget());

      // Ingresar credenciales inválidas
      await tester.enterText(find.byType(TextField).first, 'test@jualas.es');
      await tester.enterText(find.byType(TextField).last, 'wrongpassword');

      // Presionar botón de login
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Verificar que se muestra SnackBar de error
      expect(
        find.byType(SnackBar),
        findsOneWidget,
        reason: 'Debe mostrar SnackBar con mensaje de error',
      );
    });

    testWidgets('LoginScreenBloc validates empty fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Intentar hacer login sin llenar campos
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verificar que se muestra mensaje de validación
      expect(
        find.textContaining('required'),
        findsAtLeastNWidgets(1),
        reason: 'Debe mostrar mensaje de validación para campos requeridos',
      );
    });

    testWidgets('LoginScreenBloc validates email format',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Ingresar email inválido
      await tester.enterText(find.byType(TextField).first, 'invalid-email');
      await tester.enterText(find.byType(TextField).last, 'password123');

      // Presionar botón de login
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verificar que se muestra mensaje de validación de email
      expect(
        find.textContaining('email'),
        findsAtLeastNWidgets(1),
        reason: 'Debe validar formato de email',
      );
    });

    testWidgets('LoginScreenBloc toggles password visibility',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Encontrar el campo de contraseña
      final passwordField = find.byType(TextField).last;
      await tester.enterText(passwordField, 'password123');

      // Verificar que inicialmente está oculta
      final textField = tester.widget<TextField>(passwordField);
      expect(
        textField.obscureText,
        isTrue,
        reason: 'La contraseña debe estar oculta inicialmente',
      );

      // Buscar el botón de toggle de visibilidad
      final visibilityButton = find.byIcon(Icons.visibility_off);
      expect(
        visibilityButton,
        findsOneWidget,
        reason: 'Debe mostrar botón de toggle de visibilidad',
      );

      // Presionar el botón de toggle
      await tester.tap(visibilityButton);
      await tester.pump();

      // Verificar que ahora está visible
      final textFieldAfter = tester.widget<TextField>(passwordField);
      expect(
        textFieldAfter.obscureText,
        isFalse,
        reason: 'La contraseña debe estar visible después del toggle',
      );
    });

    testWidgets('LoginScreenBloc shows language selector',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Verificar que el selector de idioma está presente
      expect(
        find.byIcon(Icons.language),
        findsOneWidget,
        reason: 'Debe mostrar selector de idioma',
      );
    });
  });
}
