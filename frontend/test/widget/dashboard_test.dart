import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend/screens/dashboard/student_dashboard_screen.dart';
import 'package:frontend/blocs/auth_bloc.dart';
import 'package:frontend/blocs/anteprojects_bloc.dart';
import 'package:frontend/blocs/tasks_bloc.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/anteprojects_service.dart';
import 'package:frontend/services/tasks_service.dart';
import 'widget_test_utils.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockAnteprojectsService extends Mock implements AnteprojectsService {}

class _MockTasksService extends Mock implements TasksService {}

void main() {
  group('StudentDashboardScreen Widget Tests (Dashboard Principal)', () {
    late _MockAuthService mockAuthService;
    late _MockAnteprojectsService mockAnteprojectsService;
    late _MockTasksService mockTasksService;
    late AuthBloc authBloc;
    late AnteprojectsBloc anteprojectsBloc;
    late TasksBloc tasksBloc;

    final fakeAnteproject = WidgetTestUtils.createTestAnteproject();
    final fakeTask = {
      'id': 1,
      'title': 'Tarea de prueba',
      'status': 'completed',
    };

    setUp(() {
      mockAuthService = _MockAuthService();
      mockAnteprojectsService = _MockAnteprojectsService();
      mockTasksService = _MockTasksService();

      authBloc = AuthBloc(authService: mockAuthService);
      anteprojectsBloc = AnteprojectsBloc(
        anteprojectsService: mockAnteprojectsService,
      );
      tasksBloc = TasksBloc(tasksService: mockTasksService);

      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(
        mockAuthService.authStateChanges,
      ).thenAnswer((_) => const Stream.empty());

      when(
        mockAnteprojectsService.getStudentAnteprojects(),
      ).thenAnswer((_) async => [fakeAnteproject]);
      when(
        mockTasksService.getStudentTasks(),
      ).thenAnswer((_) async => [fakeTask]);
    });

    tearDown(() {
      authBloc.close();
      anteprojectsBloc.close();
      tasksBloc.close();
    });

    Widget createTestWidget() {
      return WidgetTestUtils.createTestApp(
        child: StudentDashboardScreen(user: WidgetTestUtils.createTestUser()),
        blocProviders: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<AnteprojectsBloc>.value(value: anteprojectsBloc),
          BlocProvider<TasksBloc>.value(value: tasksBloc),
        ],
      );
    }

    testWidgets('Dashboard shows correct title and structure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await WidgetTestUtils.waitForAnimation(tester);

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.textContaining('Dashboard'), findsOneWidget);
    });

    testWidgets('Dashboard loads student data and stats', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await WidgetTestUtils.waitForAnimation(tester);

      verify(mockAnteprojectsService.getStudentAnteprojects).called(1);
      verify(mockTasksService.getStudentTasks).called(1);

      expect(find.text('1'), findsWidgets);
      expect(find.textContaining('Tarea de prueba'), findsOneWidget);
    });

    testWidgets('Dashboard shows loading state', (WidgetTester tester) async {
      when(mockAnteprojectsService.getStudentAnteprojects()).thenAnswer((
        Invocation invocation,
      ) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return [fakeAnteproject];
      });
      when(mockTasksService.getStudentTasks()).thenAnswer((
        Invocation invocation,
      ) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return [fakeTask];
      });

      await tester.pumpWidget(createTestWidget());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('Dashboard handles data load errors gracefully', (
      WidgetTester tester,
    ) async {
      when(
        mockAnteprojectsService.getStudentAnteprojects,
      ).thenThrow(Exception('Error anteproyectos en dashboard principal'));

      await tester.pumpWidget(createTestWidget());
      await WidgetTestUtils.waitForAnimation(tester);

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Dashboard responsive design works', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      await tester.pumpWidget(createTestWidget());
      await WidgetTestUtils.waitForAnimation(tester);

      expect(find.byType(Scaffold), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
