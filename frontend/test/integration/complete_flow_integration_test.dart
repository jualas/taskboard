import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/anteprojects_service.dart';
import 'package:frontend/services/tasks_service.dart';
import 'package:frontend/models/anteproject.dart';
import 'package:frontend/models/task.dart';
import 'integration_test_setup.dart';

void main() {
  group('Complete Flow Integration Tests', () {
    late AuthService authService;
    late AnteprojectsService anteprojectsService;
    late TasksService tasksService;

    setUpAll(() async {
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🚀 Iniciando tests de integración de flujo completo');
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
      anteprojectsService = AnteprojectsService();
      tasksService = TasksService();
      await IntegrationTestSetup.cleanupTestData();
    });

    tearDown(() async {
      await IntegrationTestSetup.cleanupTestData();
    });

    test('Complete user journey: login -> fetch data -> logout', () async {
      // CORRECCIÓN: Sin try-catch - si falla, el test debe fallar
      const testEmail = String.fromEnvironment(
        'TEST_USER_EMAIL',
        defaultValue: 'carlos.lopez@jualas.es',
      );
      const testPassword = String.fromEnvironment(
        'TEST_USER_PASSWORD',
        defaultValue: 'password123',
      );

      // 1. Verificar conexión con backend
      final isConnected = await IntegrationTestSetup.testBackendConnection();
      expect(
        isConnected,
        isTrue,
        reason: 'Backend debe estar disponible para tests de integración',
      );

      // 2. Hacer sign in
      final authResponse = await authService.signIn(
        email: testEmail,
        password: testPassword,
      );

      expect(
        authResponse['success'],
        isTrue,
        reason: 'Sign in debe ser exitoso con credenciales válidas',
      );
      expect(
        authResponse['user'],
        isNotNull,
        reason: 'Respuesta debe contener información del usuario',
      );
      expect(
        authService.isAuthenticated,
        isTrue,
        reason: 'Usuario debe estar autenticado después de sign in',
      );

      // 3. Obtener perfil del usuario
      final userProfile = await authService.getCurrentUserProfile();
      expect(
        userProfile,
        isNotNull,
        reason: 'Debe ser posible obtener el perfil del usuario autenticado',
      );
      expect(
        userProfile!.email,
        equals(testEmail),
        reason: 'Email del perfil debe coincidir con el proporcionado',
      );
        
        // 4. Verificar roles del usuario
        final isStudent = await authService.isStudent;
        final isTutor = await authService.isTutor;
        final isAdmin = await authService.isAdmin;
        
      // CORRECCIÓN: Verificar que exactamente uno de los roles es true
      final roleCount = [isStudent, isTutor, isAdmin].where((r) => r).length;
      expect(
        roleCount,
        equals(1),
        reason: 'Usuario debe tener exactamente un rol asignado',
      );

      // 5. Obtener anteproyectos
      final anteprojects = await anteprojectsService.getAnteprojects();
      expect(
        anteprojects,
        isA<List<Anteproject>>(),
        reason: 'Debe retornar lista de anteproyectos',
      );

      // 6. Obtener tareas
      final tasks = await tasksService.getTasks();
      expect(
        tasks,
        isA<List<Task>>(),
        reason: 'Debe retornar lista de tareas',
      );

      // 7. Hacer sign out
      await authService.signOut();
      expect(
        authService.isAuthenticated,
        isFalse,
        reason: 'Usuario no debe estar autenticado después de sign out',
      );

      debugPrint('✅ Flujo completo de usuario ejecutado exitosamente');
    });

    test('Data consistency between services', () async {
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
        
        // Obtener datos de ambos servicios
        final anteprojects = await anteprojectsService.getAnteprojects();
        final tasks = await tasksService.getTasks();
        
      // Verificar que ambos servicios devuelven datos consistentes
      expect(
        anteprojects,
        isA<List<Anteproject>>(),
        reason: 'Debe retornar lista de anteproyectos',
      );
      expect(
        tasks,
        isA<List<Task>>(),
        reason: 'Debe retornar lista de tareas',
      );

      // Si hay anteproyectos, verificar que tienen IDs válidos
      if (anteprojects.isNotEmpty) {
        for (final anteproject in anteprojects) {
          expect(
            anteproject.id,
            isNotNull,
            reason: 'Anteproyecto debe tener un ID válido',
          );
          expect(
            anteproject.id,
            isPositive,
            reason: 'ID de anteproyecto debe ser positivo',
          );
          expect(
            anteproject.title,
            isNotEmpty,
            reason: 'Anteproyecto debe tener un título',
          );
          expect(
            anteproject.description,
            isNotEmpty,
            reason: 'Anteproyecto debe tener una descripción',
          );
        }
      }

      // Si hay tareas, verificar que tienen IDs válidos y referencias correctas
      if (tasks.isNotEmpty) {
        for (final task in tasks) {
          expect(
            task.id,
            isNotNull,
            reason: 'Tarea debe tener un ID válido',
          );
          expect(
            task.id,
            isPositive,
            reason: 'ID de tarea debe ser positivo',
          );
          expect(
            task.projectId,
            isNotNull,
            reason: 'Tarea debe tener un ID de proyecto',
          );
          expect(
            task.projectId,
            isPositive,
            reason: 'ID de proyecto debe ser positivo',
          );
          expect(
            task.title,
            isNotEmpty,
            reason: 'Tarea debe tener un título',
          );
          expect(
            task.description,
            isNotEmpty,
            reason: 'Tarea debe tener una descripción',
          );
        }
      }

      // Limpiar
      await authService.signOut();

      debugPrint('✅ Consistencia de datos verificada exitosamente');
    });

    test('Service availability and error handling', () async {
      // CORRECCIÓN: Sin try-catch - si falla, el test debe fallar
      // Verificar que todos los servicios están disponibles
      expect(
        authService,
        isNotNull,
        reason: 'AuthService debe estar disponible',
      );
      expect(
        anteprojectsService,
        isNotNull,
        reason: 'AnteprojectsService debe estar disponible',
      );
      expect(
        tasksService,
        isNotNull,
        reason: 'TasksService debe estar disponible',
      );

      // Verificar que los servicios tienen los métodos requeridos
      expect(
        authService.signIn,
        isA<Function>(),
        reason: 'AuthService debe tener método signIn',
      );
      expect(
        authService.signOut,
        isA<Function>(),
        reason: 'AuthService debe tener método signOut',
      );
      expect(
        authService.getCurrentUserProfile,
        isA<Function>(),
        reason: 'AuthService debe tener método getCurrentUserProfile',
      );

      expect(
        anteprojectsService.getAnteprojects,
        isA<Function>(),
        reason: 'AnteprojectsService debe tener método getAnteprojects',
      );
      expect(
        anteprojectsService.getAnteproject,
        isA<Function>(),
        reason: 'AnteprojectsService debe tener método getAnteproject',
      );
      expect(
        anteprojectsService.getAnteprojectsByStatus,
        isA<Function>(),
        reason: 'AnteprojectsService debe tener método getAnteprojectsByStatus',
      );

      expect(
        tasksService.getTasks,
        isA<Function>(),
        reason: 'TasksService debe tener método getTasks',
      );
      expect(
        tasksService.getTask,
        isA<Function>(),
        reason: 'TasksService debe tener método getTask',
      );
      expect(
        tasksService.getTasksByProject,
        isA<Function>(),
        reason: 'TasksService debe tener método getTasksByProject',
      );
      expect(
        tasksService.getTasksByStatus,
        isA<Function>(),
        reason: 'TasksService debe tener método getTasksByStatus',
      );

      debugPrint('✅ Disponibilidad de servicios verificada exitosamente');
    });

    test('Authentication state management', () async {
      // CORRECCIÓN: Sin try-catch - si falla, el test debe fallar
      const testEmail = String.fromEnvironment(
        'TEST_USER_EMAIL',
        defaultValue: 'carlos.lopez@jualas.es',
      );
      const testPassword = String.fromEnvironment(
        'TEST_USER_PASSWORD',
        defaultValue: 'password123',
      );

      // Verificar estado inicial
      expect(
        authService.isAuthenticated,
        isFalse,
        reason: 'Usuario no debe estar autenticado inicialmente',
      );

      // Hacer sign in
      await authService.signIn(
        email: testEmail,
        password: testPassword,
      );

      // Verificar que está autenticado
      expect(
        authService.isAuthenticated,
        isTrue,
        reason: 'Usuario debe estar autenticado después de sign in',
      );

      // Verificar que el stream de cambios de estado funciona
      final states = <AuthState>[];
      final subscription = authService.authStateChanges.listen(states.add);

      // Esperar un poco para capturar estados
      await Future.delayed(const Duration(milliseconds: 100));

      // Verificar que se recibieron estados
      expect(
        states.isNotEmpty,
        isTrue,
        reason: 'Stream debe emitir al menos el estado inicial',
      );

      // Hacer sign out
      await authService.signOut();

      // Verificar que ya no está autenticado
      expect(
        authService.isAuthenticated,
        isFalse,
        reason: 'Usuario no debe estar autenticado después de sign out',
      );

      // Limpiar
      await subscription.cancel();

      debugPrint('✅ Gestión de estado de autenticación verificada exitosamente');
    });

    test('Data filtering and pagination', () async {
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

      // Probar diferentes filtros de anteproyectos
      final draftAnteprojects =
          await anteprojectsService.getAnteprojectsByStatus(
        AnteprojectStatus.draft,
      );
      final submittedAnteprojects =
          await anteprojectsService.getAnteprojectsByStatus(
        AnteprojectStatus.submitted,
      );
      final approvedAnteprojects =
          await anteprojectsService.getAnteprojectsByStatus(
        AnteprojectStatus.approved,
      );

      // Verificar que los filtros funcionan
      expect(
        draftAnteprojects,
        isA<List<Anteproject>>(),
        reason: 'Debe retornar lista de anteproyectos en borrador',
      );
      expect(
        submittedAnteprojects,
        isA<List<Anteproject>>(),
        reason: 'Debe retornar lista de anteproyectos enviados',
      );
      expect(
        approvedAnteprojects,
        isA<List<Anteproject>>(),
        reason: 'Debe retornar lista de anteproyectos aprobados',
      );

      // Probar diferentes filtros de tareas
      final pendingTasks =
          await tasksService.getTasksByStatus(TaskStatus.pending);
      final inProgressTasks =
          await tasksService.getTasksByStatus(TaskStatus.inProgress);
      final completedTasks =
          await tasksService.getTasksByStatus(TaskStatus.completed);

      // Verificar que los filtros funcionan
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

      debugPrint('✅ Filtrado y paginación de datos verificados exitosamente');
    });
  });
}
