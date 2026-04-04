import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/projects/projects_list_screen.dart';
import '../screens/kanban/kanban_board.dart';
import '../screens/lists/tasks_list.dart';

/// Router simplificado para la aplicación TaskBoard Personal
class AppRouter {
  final AuthService authService;
  final Listenable? authRefreshListenable;
  late final GoRouter router;

  AppRouter({
    required this.authService,
    this.authRefreshListenable,
  }) {
    router = GoRouter(
      initialLocation: '/login',
      debugLogDiagnostics: true,
      refreshListenable: authRefreshListenable,
      redirect: (context, state) {
        final isAuthenticated = authService.isAuthenticated;
        final isLoggingIn = state.matchedLocation == '/login';

        // Si no está autenticado y no está en login, redirigir a login
        if (!isAuthenticated && !isLoggingIn) {
          return '/login';
        }

        // Si está autenticado y está en login, redirigir a proyectos
        if (isAuthenticated && isLoggingIn) {
          return '/projects';
        }

        return null;
      },
      routes: [
        // Ruta de Login
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        
        // Ruta de Lista de Proyectos
        GoRoute(
          path: '/projects',
          name: 'projects',
          builder: (context, state) => const ProjectsListScreen(),
          routes: [
            // Ruta de Kanban para un proyecto
            GoRoute(
              path: ':projectId/kanban',
              name: 'kanban',
              builder: (context, state) {
                final projectId = int.parse(state.pathParameters['projectId']!);
                return KanbanBoard(projectId: projectId);
              },
            ),
            
            // Ruta de Lista de Tareas para un proyecto
            GoRoute(
              path: ':projectId/tasks',
              name: 'tasks',
              builder: (context, state) {
                final projectId = int.parse(state.pathParameters['projectId']!);
                return TasksList(projectId: projectId);
              },
            ),
          ],
        ),
      ],
      
      // Página de error
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Página no encontrada',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                state.matchedLocation,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/projects'),
                child: const Text('Ir a Proyectos'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
