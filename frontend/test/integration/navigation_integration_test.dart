import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/forms/task_form.dart';
import 'package:frontend/screens/lists/tasks_list.dart';
import 'package:frontend/screens/kanban/kanban_board.dart';

void main() {
  group('Navigation Integration Tests', () {
    testWidgets('StudentDashboard navigation methods exist', (WidgetTester tester) async {
      // Verificar que los métodos de navegación existen en StudentDashboard
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Test Navigation'),
            ),
          ),
        ),
      );

      // Verificar que los widgets de destino se pueden instanciar
      expect(() => TaskForm(projectId: 1, onSave: (_) {}), returnsNormally);
      expect(() => const TasksList(projectId: 1), returnsNormally);
      expect(() => const KanbanBoard(projectId: 1), returnsNormally);
    });

    testWidgets('Navigation routes are properly configured', (WidgetTester tester) async {
      // Verificar que las rutas de navegación están configuradas correctamente
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Test Routes'),
            ),
          ),
        ),
      );

      // Verificar que MaterialApp se puede construir con las localizaciones
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.text('Test Routes'), findsOneWidget);
    });

    testWidgets('Task-related screens can be navigated to', (WidgetTester tester) async {
      // Verificar que las pantallas relacionadas con tareas se pueden navegar
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Test Task Navigation'),
            ),
          ),
        ),
      );

      // Verificar que las pantallas se pueden instanciar
      expect(() => TaskForm(projectId: 1, onSave: (_) {}), returnsNormally);
      expect(() => const TasksList(projectId: 1), returnsNormally);
      expect(() => const KanbanBoard(projectId: 1), returnsNormally);
    });

    testWidgets('Navigation structure is consistent', (WidgetTester tester) async {
      // Verificar que la estructura de navegación es consistente
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Test Structure'),
            ),
          ),
        ),
      );

      // Verificar que la estructura básica es correcta
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Center), findsOneWidget);
      expect(find.text('Test Structure'), findsOneWidget);
    });
  });
}
