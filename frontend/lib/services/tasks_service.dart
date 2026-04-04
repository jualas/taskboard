import '../models/models.dart';
import 'taskboard_data_source.dart';

/// Servicio para la gestión de tareas y sistema Kanban.
class TasksService {
  final TaskboardDataSource _dataSource;

  TasksService(this._dataSource);

  /// Obtiene todas las tareas
  Future<List<Task>> getTasks() async {
    return _dataSource.getTasks();
  }

  /// Obtiene las tareas de un proyecto
  Future<List<Task>> getTasksByProject(int projectId) async {
    final tasks = await _dataSource.getTasksByProject(projectId);
    // Ordenar por posición Kanban
    tasks.sort((a, b) => a.kanbanPosition.compareTo(b.kanbanPosition));
    return tasks;
  }

  /// Obtiene una tarea por ID
  Future<Task?> getTask(int id) async {
    return _dataSource.getTask(id);
  }

  /// Crea una nueva tarea
  Future<Task> createTask({
    required int projectId,
    required String title,
    String description = '',
    TaskStatus status = TaskStatus.pending,
    DateTime? dueDate,
    int? estimatedHours,
    TaskComplexity complexity = TaskComplexity.simple,
    List<String> tags = const [],
    List<Subtask> subtasks = const [],
  }) async {
    final id = await _dataSource.getNextTaskId();
    
    // Calcular la posición Kanban (al final de la columna)
    final projectTasks = await getTasksByProject(projectId);
    final sameStatusTasks = projectTasks.where((t) => t.status == status).toList();
    final kanbanPosition = sameStatusTasks.isEmpty 
        ? 1.0 
        : sameStatusTasks.map((t) => t.kanbanPosition).reduce((a, b) => a > b ? a : b) + 1;
    
    final task = Task.create(
      id: id,
      projectId: projectId,
      title: title,
      description: description,
      status: status,
      dueDate: dueDate,
      kanbanPosition: kanbanPosition,
      estimatedHours: estimatedHours,
      complexity: complexity,
      tags: tags,
      subtasks: subtasks,
    );
    
    return _dataSource.saveTask(task);
  }

  /// Actualiza una tarea existente
  Future<Task> updateTask(Task task) async {
    return _dataSource.saveTask(task);
  }

  /// Elimina una tarea
  Future<void> deleteTask(int id) async {
    await _dataSource.deleteTask(id);
  }

  /// Cambia el estado de una tarea
  Future<Task> updateTaskStatus(int id, TaskStatus status) async {
    final task = await _dataSource.getTask(id);
    if (task == null) {
      throw Exception('Tarea no encontrada');
    }
    
    // Recalcular posición Kanban para la nueva columna
    final projectTasks = await getTasksByProject(task.projectId);
    final sameStatusTasks = projectTasks
        .where((t) => t.status == status && t.id != id)
        .toList();
    final kanbanPosition = sameStatusTasks.isEmpty 
        ? 1.0 
        : sameStatusTasks.map((t) => t.kanbanPosition).reduce((a, b) => a > b ? a : b) + 1;
    
    final updatedTask = task.copyWith(
      status: status,
      kanbanPosition: kanbanPosition,
      updatedAt: DateTime.now(),
    );
    
    return _dataSource.saveTask(updatedTask);
  }

  /// Mueve una tarea en el Kanban (cambio de columna y/o posición)
  Future<Task> moveTask({
    required int taskId,
    required TaskStatus newStatus,
    required int targetIndex,
  }) async {
    final task = await _dataSource.getTask(taskId);
    if (task == null) {
      throw Exception('Tarea no encontrada');
    }

    final projectTasks = await getTasksByProject(task.projectId);
    
    // Obtener tareas de la columna destino (excluyendo la tarea actual)
    final targetColumnTasks = projectTasks
        .where((t) => t.status == newStatus && t.id != taskId)
        .toList()
      ..sort((a, b) => a.kanbanPosition.compareTo(b.kanbanPosition));

    // Calcular nueva posición
    double newPosition;
    if (targetColumnTasks.isEmpty) {
      newPosition = 1.0;
    } else if (targetIndex <= 0) {
      // Insertar al principio
      newPosition = targetColumnTasks.first.kanbanPosition / 2;
    } else if (targetIndex >= targetColumnTasks.length) {
      // Insertar al final
      newPosition = targetColumnTasks.last.kanbanPosition + 1;
    } else {
      // Insertar entre dos tareas
      final prevPosition = targetColumnTasks[targetIndex - 1].kanbanPosition;
      final nextPosition = targetColumnTasks[targetIndex].kanbanPosition;
      newPosition = (prevPosition + nextPosition) / 2;
    }

    final updatedTask = task.copyWith(
      status: newStatus,
      kanbanPosition: newPosition,
      updatedAt: DateTime.now(),
    );

    return _dataSource.saveTask(updatedTask);
  }

  /// Obtiene tareas por estado
  Future<List<Task>> getTasksByStatus(int projectId, TaskStatus status) async {
    final tasks = await getTasksByProject(projectId);
    return tasks.where((t) => t.status == status).toList();
  }

  /// Obtiene tareas con fecha límite próxima
  Future<List<Task>> getTasksWithUpcomingDeadline({
    int? projectId,
    int daysAhead = 7,
  }) async {
    final tasks = projectId != null 
        ? await getTasksByProject(projectId)
        : await getTasks();
    
    final deadline = DateTime.now().add(Duration(days: daysAhead));
    
    return tasks
        .where((t) => 
            t.status != TaskStatus.completed &&
            t.dueDate != null &&
            t.dueDate!.isBefore(deadline))
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  }

  /// Recalcula las posiciones Kanban de un proyecto
  Future<void> recalculateKanbanPositions(int projectId) async {
    final tasks = await getTasksByProject(projectId);
    
    for (final status in TaskStatus.values) {
      final statusTasks = tasks
          .where((t) => t.status == status)
          .toList()
        ..sort((a, b) => a.kanbanPosition.compareTo(b.kanbanPosition));
      
      for (int i = 0; i < statusTasks.length; i++) {
        final task = statusTasks[i];
        if (task.kanbanPosition != (i + 1).toDouble()) {
          await _dataSource.saveTask(
            task.copyWith(kanbanPosition: (i + 1).toDouble()),
          );
        }
      }
    }
  }
}
