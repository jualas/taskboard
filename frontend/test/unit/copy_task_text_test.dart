import 'package:flutter_test/flutter_test.dart';
import 'package:personal_taskboard/features/tasks/domain/entities/task.dart';
import 'package:personal_taskboard/features/tasks/presentation/utils/copy_task_text.dart';

void main() {
  final t = DateTime(2026, 1, 1);
  Task tarea({
    String description = '',
    List<String> tags = const [],
    List<Subtask> subtasks = const [],
    int? hours,
    DateTime? due,
  }) => Task(
    id: 1,
    projectId: 1,
    title: '  Revisar contrato ',
    description: description,
    status: TaskStatus.inProgress,
    dueDate: due,
    kanbanPosition: 0,
    estimatedHours: hours,
    complexity: TaskComplexity.medium,
    tags: tags,
    subtasks: subtasks,
    createdAt: t,
    updatedAt: t,
  );

  test('tarea mínima: título y estado', () {
    expect(
      taskAsPlainText(tarea()),
      'Revisar contrato\nEn Progreso · Complejidad: Media',
    );
  });

  test('tarea completa: metadatos, descripción y checklist', () {
    final texto = taskAsPlainText(
      tarea(
        description: 'Línea 1\nLínea 2\n',
        tags: const ['legal', 'urgente'],
        hours: 3,
        due: DateTime(2026, 3, 5),
        subtasks: const [
          Subtask(id: 1, title: 'Leer', isDone: true),
          Subtask(id: 2, title: 'Firmar'),
        ],
      ),
    );
    expect(
      texto,
      'Revisar contrato\n'
      'En Progreso · Complejidad: Media · 3 h · Vence: 05/03/2026\n'
      'Etiquetas: legal, urgente\n'
      '\n'
      'Línea 1\nLínea 2\n'
      '\n'
      'Checklist (1/2):\n'
      '- [x] Leer\n'
      '- [ ] Firmar',
    );
  });
}
