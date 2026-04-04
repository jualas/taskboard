import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/task.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/tasks_service.dart';
import 'integration_test_setup.dart';

import 'package:flutter/foundation.dart';

void main() {
  group('Tasks Integration Tests', () {
    late AuthService authService;
    late TasksService tasksService;

    setUpAll(() async {
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🚀 Iniciando tests de integración de tareas');
      debugPrint('═══════════════════════════════════════════════════════════');
      
      // Inicializar Supabase usando variables de entorno
      // initializeSupabase() ahora incluye verificación automática de conexión
      // y lanzará StateError si el backend no está disponible
      await IntegrationTestSetup.initializeSupabase();
      
      debugPrint('✅ Setup completado. Iniciando tests...');
      debugPrint('');
    });

    setUp(() async {
      authService = AuthService();
      tasksService = TasksService();
      await IntegrationTestSetup.cleanupTestData();
    });

    tearDown(() async {
      await IntegrationTestSetup.cleanupTestData();
    });

    test('Can authenticate and access tasks service', () async {
      // CORRECCIÓN: Sin try-catch - si falla, el test debe fallar
      const testEmail = String.fromEnvironment(
        'TEST_USER_EMAIL',
        defaultValue: 'carlos.lopez@jualas.es',
      );
      const testPassword = String.fromEnvironment(
        'TEST_USER_PASSWORD',
        defaultValue: 'password123',
      );

      // Hacer sign in
      await authService.signIn(
        email: testEmail,
        password: testPassword,
      );

      expect(
        authService.isAuthenticated,
        isTrue,
        reason: 'Usuario debe estar autenticado después de sign in',
      );

      // Verificar que el servicio está disponible
      expect(
        tasksService,
        isNotNull,
        reason: 'TasksService debe estar disponible',
      );

      // Limpiar
      await authService.signOut();
    });

    test('Can fetch tasks from backend', () async {
      // CORRECCIÓN: Sin try-catch - si falla, el test debe fallar
      const testEmail = String.fromEnvironment(
        'TEST_USER_EMAIL',
        defaultValue: 'carlos.lopez@jualas.es',
      );
      const testPassword = String.fromEnvironment(
        'TEST_USER_PASSWORD',
        defaultValue: 'password123',
      );

      // Hacer sign in
      await authService.signIn(
        email: testEmail,
        password: testPassword,
      );

      // Obtener tareas
      final tasks = await tasksService.getTasks();

      // Verificar que se obtuvieron datos (puede estar vacío)
      expect(
        tasks,
        isA<List<Task>>(),
        reason: 'Debe retornar una lista de tareas',
      );

      // Si hay tareas, verificar estructura
      if (tasks.isNotEmpty) {
        final firstTask = tasks.first;
        expect(
          firstTask.id,
          isNotNull,
          reason: 'Tarea debe tener un ID válido',
        );
        expect(
          firstTask.title,
          isNotEmpty,
          reason: 'Tarea debe tener un título',
        );
        expect(
          firstTask.description,
          isNotEmpty,
          reason: 'Tarea debe tener una descripción',
        );
        expect(
          firstTask.status,
          isNotNull,
          reason: 'Tarea debe tener un estado',
        );
        expect(
          firstTask.projectId,
          isNotNull,
          reason: 'Tarea debe tener un ID de proyecto',
        );
      }

      // Limpiar
      await authService.signOut();
    });

    test('Can fetch tasks by project', () async {
      // CORRECCIÓN: Sin try-catch - si falla, el test debe fallar
      const testEmail = String.fromEnvironment(
        'TEST_USER_EMAIL',
        defaultValue: 'carlos.lopez@jualas.es',
      );
      const testPassword = String.fromEnvironment(
        'TEST_USER_PASSWORD',
        defaultValue: 'password123',
      );

      // Hacer sign in
      await authService.signIn(
        email: testEmail,
        password: testPassword,
      );

      // Obtener tareas por proyecto (usar ID 1 como ejemplo)
      final projectTasks = await tasksService.getTasksByProject(1);

      // Verificar que se obtuvieron datos (puede estar vacío)
      expect(
        projectTasks,
        isA<List<Task>>(),
        reason: 'Debe retornar una lista de tareas del proyecto',
      );

      // Si hay tareas, verificar que pertenecen al proyecto correcto
      if (projectTasks.isNotEmpty) {
        for (final task in projectTasks) {
          expect(
            task.projectId,
            equals(1),
            reason: 'Tarea debe pertenecer al proyecto especificado',
          );
          expect(
            task.id,
            isNotNull,
            reason: 'Tarea debe tener un ID válido',
          );
          expect(
            task.title,
            isNotEmpty,
            reason: 'Tarea debe tener un título',
          );
        }
      }

      // Limpiar
      await authService.signOut();
    });

    test('Can fetch tasks by status', () async {
      // CORRECCIÓN: Sin try-catch - si falla, el test debe fallar
      const testEmail = String.fromEnvironment(
        'TEST_USER_EMAIL',
        defaultValue: 'carlos.lopez@jualas.es',
      );
      const testPassword = String.fromEnvironment(
        'TEST_USER_PASSWORD',
        defaultValue: 'password123',
      );

      // Hacer sign in
      await authService.signIn(
        email: testEmail,
        password: testPassword,
      );

      // Obtener tareas por diferentes estados
      final pendingTasks =
          await tasksService.getTasksByStatus(TaskStatus.pending);
      final inProgressTasks =
          await tasksService.getTasksByStatus(TaskStatus.inProgress);
      final completedTasks =
          await tasksService.getTasksByStatus(TaskStatus.completed);

      // Verificar que se obtuvieron listas válidas
      expect(
        pendingTasks,
        isA<List<Task>>(),
        reason: 'Debe retornar lista de tareas pendientes',
      );
      expect(
        inProgressTasks,
        isA<List<Task>>(),
        reason: 'Debe retornar lista de tareas en progreso',
      );
      expect(
        completedTasks,
        isA<List<Task>>(),
        reason: 'Debe retornar lista de tareas completadas',
      );

      // Limpiar
      await authService.signOut();
    });

    test('Can fetch task by ID', () async {
      // CORRECCIÓN: Sin try-catch - si falla, el test debe fallar
      const testEmail = String.fromEnvironment(
        'TEST_USER_EMAIL',
        defaultValue: 'carlos.lopez@jualas.es',
      );
      const testPassword = String.fromEnvironment(
        'TEST_USER_PASSWORD',
        defaultValue: 'password123',
      );

      // Hacer sign in
      await authService.signIn(
        email: testEmail,
        password: testPassword,
      );

      // Primero obtener lista de tareas
      final tasks = await tasksService.getTasks();

      if (tasks.isNotEmpty) {
        final firstTask = tasks.first;

        // Obtener tarea por ID
        final fetchedTask = await tasksService.getTask(firstTask.id);

        // Verificar que se obtuvo la tarea correcta
        expect(
          fetchedTask,
          isNotNull,
          reason: 'Debe retornar la tarea solicitada',
        );
        expect(
          fetchedTask!.id,
          equals(firstTask.id),
          reason: 'ID de la tarea debe coincidir',
        );
        expect(
          fetchedTask.title,
          equals(firstTask.title),
          reason: 'Título de la tarea debe coincidir',
        );
      }

      // Limpiar
      await authService.signOut();
    });

    test('Can fetch tasks by complexity', () async {
      // CORRECCIÓN: Sin try-catch - si falla, el test debe fallar
      const testEmail = String.fromEnvironment(
        'TEST_USER_EMAIL',
        defaultValue: 'carlos.lopez@jualas.es',
      );
      const testPassword = String.fromEnvironment(
        'TEST_USER_PASSWORD',
        defaultValue: 'password123',
      );

      // Hacer sign in
      await authService.signIn(
        email: testEmail,
        password: testPassword,
      );

      // Obtener tareas por diferentes complejidades
      final simpleTasks =
          await tasksService.getTasksByComplexity(TaskComplexity.simple);
      final mediumTasks =
          await tasksService.getTasksByComplexity(TaskComplexity.medium);
      final complexTasks =
          await tasksService.getTasksByComplexity(TaskComplexity.complex);

      // Verificar que se obtuvieron listas válidas
      expect(
        simpleTasks,
        isA<List<Task>>(),
        reason: 'Debe retornar lista de tareas simples',
      );
      expect(
        mediumTasks,
        isA<List<Task>>(),
        reason: 'Debe retornar lista de tareas de complejidad media',
      );
      expect(
        complexTasks,
        isA<List<Task>>(),
        reason: 'Debe retornar lista de tareas complejas',
      );

      // Limpiar
      await authService.signOut();
    });

    test('Can fetch tasks with upcoming deadlines', () async {
      // CORRECCIÓN: Sin try-catch - si falla, el test debe fallar
      const testEmail = String.fromEnvironment(
        'TEST_USER_EMAIL',
        defaultValue: 'carlos.lopez@jualas.es',
      );
      const testPassword = String.fromEnvironment(
        'TEST_USER_PASSWORD',
        defaultValue: 'password123',
      );

      // Hacer sign in
      await authService.signIn(
        email: testEmail,
        password: testPassword,
      );

      // Obtener tareas con fechas límite próximas
      final upcomingTasks =
          await tasksService.getTasksWithUpcomingDeadline(daysAhead: 7);

      // Verificar que se obtuvieron datos (puede estar vacío)
      expect(
        upcomingTasks,
        isA<List<Task>>(),
        reason: 'Debe retornar lista de tareas con fechas límite próximas',
      );

      // Si hay tareas, verificar estructura
      if (upcomingTasks.isNotEmpty) {
        for (final task in upcomingTasks) {
          expect(
            task.id,
            isNotNull,
            reason: 'Tarea debe tener un ID válido',
          );
          expect(
            task.dueDate,
            isNotNull,
            reason: 'Tarea debe tener una fecha límite',
          );
        }
      }

      // Limpiar
      await authService.signOut();
    });

    test('Fetching non-existent task throws exception', () async {
      // CORRECCIÓN: Test de caso de fallo - ID inexistente
      const testEmail = String.fromEnvironment(
        'TEST_USER_EMAIL',
        defaultValue: 'carlos.lopez@jualas.es',
      );
      const testPassword = String.fromEnvironment(
        'TEST_USER_PASSWORD',
        defaultValue: 'password123',
      );

      // Hacer sign in
      await authService.signIn(
        email: testEmail,
        password: testPassword,
      );

      // Intentar obtener una tarea con ID que no existe
      // Usar un ID muy grande que seguramente no existe
      const nonExistentId = 999999;

      // Debe lanzar una excepción cuando el ID no existe
      expect(
        () async => await tasksService.getTask(nonExistentId),
        throwsA(anything),
        reason: 'Obtener tarea con ID inexistente debe lanzar una excepción',
      );

      // Limpiar
      await authService.signOut();
    });
  });
}
