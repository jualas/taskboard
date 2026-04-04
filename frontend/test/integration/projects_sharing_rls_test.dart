import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:personal_taskboard/models/models.dart';
import 'package:personal_taskboard/services/auth_service.dart';
import 'package:personal_taskboard/services/projects_service.dart';
import 'package:personal_taskboard/services/tasks_service.dart';
import 'package:personal_taskboard/services/supabase/supabase_data_source.dart';
import 'integration_test_setup.dart';

/// Pruebas de integración de RLS para colaboración en proyectos:
/// - owner crea proyecto + tarea
/// - viewer no miembro no ve datos
/// - tras compartir como viewer, el usuario puede leer
/// - viewer no puede modificar tareas
void main() {
  group('Projects sharing RLS', () {
    late AuthService authService;
    late ProjectsService projectsService;
    late TasksService tasksService;

    const testPassword = 'TestPassword123!';

    setUpAll(() async {
      await IntegrationTestSetup.initializeSupabase();
    });

    setUp(() async {
      authService = AuthService();
      await IntegrationTestSetup.cleanupTestData();

      final dataSource = SupabaseDataSource(Supabase.instance.client);
      projectsService = ProjectsService(dataSource);
      tasksService = TasksService(dataSource);
    });

    tearDown(() async {
      try {
        await authService.logout();
      } catch (_) {
        // ignore
      }
      await IntegrationTestSetup.cleanupTestData();
    });

    test('Viewer can read after sharing, but cannot update tasks', () async {
      final userA = await IntegrationTestSetup.createTestUser();
      final userB = await IntegrationTestSetup.createTestUser();

      final emailA = userA.user!.email;
      final emailB = userB.user!.email;

      // OWNER: crea proyecto y tarea
      await authService.login(email: emailA, password: testPassword);

      final project = await projectsService.createProject(
        title: 'Proyecto RLS',
        description: 'Compartido',
        status: ProjectStatus.planning,
      );

      final task = await tasksService.createTask(
        projectId: project.id,
        title: 'Tarea RLS',
        description: 'Solo visible para miembros',
        status: TaskStatus.pending,
        tags: const [],
        subtasks: const [],
      );

      // Ensure owner can see
      final ownerTasks = await tasksService.getTasksByProject(project.id);
      expect(ownerTasks, isNotEmpty);

      // VIEWER NO MIEMBRO: no debe ver proyecto/tarea
      await authService.logout();
      await authService.login(email: emailB, password: testPassword);

      final viewerProjects = await projectsService.getProjects();
      expect(viewerProjects.where((p) => p.id == project.id), isEmpty);

      final viewerTasks = await tasksService.getTasksByProject(project.id);
      expect(viewerTasks, isEmpty);

      // Ahora compartir como viewer
      await authService.logout();
      await authService.login(email: emailA, password: testPassword);
      await projectsService.addMember(
        projectId: project.id,
        userId: userB.user!.id,
        role: ProjectMemberRole.viewer,
      );

      // VIEWER: ya debe poder leer
      await authService.logout();
      await authService.login(email: emailB, password: testPassword);

      final viewerProjectsAfterShare = await projectsService.getProjects();
      expect(
        viewerProjectsAfterShare.any((p) => p.id == project.id),
        isTrue,
      );

      final viewerTasksAfterShare =
          await tasksService.getTasksByProject(project.id);
      expect(viewerTasksAfterShare, isNotEmpty);

      // VIEWER: no debe poder actualizar tareas
      final updatedTask = task.copyWith(
        title: 'Intento de actualización por viewer',
        updatedAt: DateTime.now(),
      );

      await expectLater(
        () => tasksService.updateTask(updatedTask),
        throwsA(anything),
      );
    });
  });
}

