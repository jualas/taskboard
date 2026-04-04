import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend/screens/lists/tasks_list.dart';
import 'package:frontend/blocs/tasks_bloc.dart';
import 'package:frontend/blocs/auth_bloc.dart';
import 'package:frontend/models/task.dart';
import 'widget_test_utils.dart';
import 'widget_test_utils.mocks.dart';

void main() {
  group('TasksList Widget Tests', () {
    late MockTasksService mockTasksService;
    late MockAuthService mockAuthService;
    late TasksBloc tasksBloc;
    late AuthBloc authBloc;

    setUp(() {
      mockTasksService = MockTasksService();
      mockAuthService = MockAuthService();

      // Configurar mocks básicos
      WidgetTestUtils.setupBasicMocks(
        mockAuthService: mockAuthService,
        mockAnteprojectsService: MockAnteprojectsService(),
        mockTasksService: mockTasksService,
      );

      tasksBloc = TasksBloc(tasksService: mockTasksService);
      authBloc = AuthBloc(authService: mockAuthService);

      // Configurar usuario autenticado
      authBloc.add(AuthUserChanged(
        user: WidgetTestUtils.createTestUser(),
      ));
    });

    tearDown(() {
      tasksBloc.close();
      authBloc.close();
    });

    Widget createTestWidget({int? projectId}) {
      return WidgetTestUtils.createTestApp(
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<TasksBloc>.value(value: tasksBloc),
          ],
          child: TasksList(projectId: projectId),
        ),
      );
    }

    testWidgets('TasksList shows loading state', (
      WidgetTester tester,
    ) async {
      // Configurar mock para que retorne después de un delay
      when(mockTasksService.getProjectTasksForUser(any)).thenAnswer(
        (_) async {
          await Future.delayed(const Duration(milliseconds: 200));
          return [];
        },
      );

      await tester.pumpWidget(createTestWidget(projectId: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verificar que se muestra el indicador de carga
      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: 'Debe mostrar CircularProgressIndicator durante la carga',
      );
    });

    testWidgets('TasksList shows error state', (
      WidgetTester tester,
    ) async {
      // Configurar mock para que lance error
      when(mockTasksService.getProjectTasksForUser(any)).thenThrow(
        Exception('Error al cargar tareas'),
      );

      await tester.pumpWidget(createTestWidget(projectId: 1));
      await tester.pumpAndSettle();

      // Verificar que se muestra el estado de error
      expect(
        find.byIcon(Icons.error_outline),
        findsOneWidget,
        reason: 'Debe mostrar icono de error',
      );
      expect(
        find.byType(ElevatedButton),
        findsOneWidget,
        reason: 'Debe mostrar botón de retry',
      );
    });

    testWidgets('TasksList shows empty state', (
      WidgetTester tester,
    ) async {
      // Configurar mock para retornar lista vacía
      when(mockTasksService.getProjectTasksForUser(any)).thenAnswer(
        (_) async => [],
      );

      await tester.pumpWidget(createTestWidget(projectId: 1));
      await tester.pumpAndSettle();

      // Verificar que se muestra el estado vacío
      expect(
        find.byIcon(Icons.task_alt),
        findsOneWidget,
        reason: 'Debe mostrar icono de lista vacía',
      );
      expect(
        find.byType(ElevatedButton),
        findsOneWidget,
        reason: 'Debe mostrar botón de crear tarea',
      );
    });

    testWidgets('TasksList shows list with tasks', (
      WidgetTester tester,
    ) async {
      // Configurar mock para retornar tareas
      final tasks = [
        WidgetTestUtils.createTestTask(
          id: 1,
          status: TaskStatus.pending,
        ),
        WidgetTestUtils.createTestTask(
          id: 2,
          status: TaskStatus.inProgress,
        ),
      ];

      when(mockTasksService.getProjectTasksForUser(any)).thenAnswer(
        (_) async => tasks,
      );

      await tester.pumpWidget(createTestWidget(projectId: 1));
      await tester.pumpAndSettle();

      // Verificar que se muestra la lista
      expect(
        find.byType(ListView),
        findsOneWidget,
        reason: 'Debe mostrar ListView con tareas',
      );
      expect(
        find.byType(Card),
        findsNWidgets(2),
        reason: 'Debe mostrar 2 cards de tareas',
      );
    });

    testWidgets('TasksList shows FloatingActionButton for creating tasks', (
      WidgetTester tester,
    ) async {
      // Configurar mock para retornar lista vacía
      when(mockTasksService.getProjectTasksForUser(any)).thenAnswer(
        (_) async => [],
      );

      await tester.pumpWidget(createTestWidget(projectId: 1));
      await tester.pumpAndSettle();

      // Verificar que se muestra el FloatingActionButton
      expect(
        find.byType(FloatingActionButton),
        findsOneWidget,
        reason: 'Debe mostrar FloatingActionButton para crear tareas',
      );
      expect(
        find.byIcon(Icons.add),
        findsOneWidget,
        reason: 'Debe mostrar icono de agregar',
      );
    });
  });
}