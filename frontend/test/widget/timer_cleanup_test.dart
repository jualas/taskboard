import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/screens/dashboard/tutor_dashboard.dart';
import 'package:frontend/blocs/auth_bloc.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/models/user.dart';
import '../test_setup.dart';
import '../mocks/supabase_mock.dart';

const bool _runSupabaseTests = bool.fromEnvironment('RUN_SUPABASE_TESTS');

void main() {
  group('Timer Cleanup Tests', () {
    late AuthBloc authBloc;
    late AuthService authService;
    late User testUser;

    setUpAll(() async {
      await TestSetup.initializeSupabase();
    });

    setUp(() {
      authService = AuthService();
      authBloc = AuthBloc(authService: authService);
      testUser = User(
        id: 1,
        email: 'tutor@example.com',
        fullName: 'Test Tutor',
        role: UserRole.tutor,
        status: UserStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    tearDown(() {
      authBloc.close();
    });

    tearDownAll(() async {
      await TestSetup.cleanup();
    });

    testWidgets('TutorDashboard handles timers correctly', (
      WidgetTester tester,
    ) async {
      // Configurar usuario tutor
      MockSupabase.setAuthenticatedUser(
        id: 'tutor-id',
        email: 'tutor@example.com',
        role: 'tutor',
      );

      await tester.pumpWidget(
        TestSetup.createTestApp(
          child: BlocProvider<AuthBloc>(
            create: (context) => authBloc,
            child: TutorDashboard(user: testUser),
          ),
        ),
      );

      // Esperar a que se complete la animación inicial
      await tester.pumpAndSettle();

      // Verificar que el dashboard se renderiza correctamente
      expect(find.byType(TutorDashboard), findsOneWidget);

      // Simular interacciones que podrían crear timers
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Verificar que no hay timers pendientes
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('Dashboard handles async operations without timer leaks', (
      WidgetTester tester,
    ) async {
      MockSupabase.setAuthenticatedUser(role: 'tutor');

      await tester.pumpWidget(
        TestSetup.createTestApp(
          child: BlocProvider<AuthBloc>(
            create: (context) => authBloc,
            child: TutorDashboard(user: testUser),
          ),
        ),
      );

      // Simular múltiples operaciones asíncronas
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
      }

      // Verificar que no hay timers pendientes
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('Dashboard cleanup prevents timer leaks', (
      WidgetTester tester,
    ) async {
      MockSupabase.setAuthenticatedUser(role: 'tutor');

      // Crear y destruir múltiples instancias del dashboard
      for (int i = 0; i < 3; i++) {
        await tester.pumpWidget(
          TestSetup.createTestApp(
            child: BlocProvider<AuthBloc>(
              create: (context) => authBloc,
              child: TutorDashboard(user: testUser),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Remover el widget
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }

      // Verificar que no hay timers pendientes
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }, skip: !_runSupabaseTests);
}
