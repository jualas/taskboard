import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/models.dart';
import '../services/tasks_service.dart';

// Events
abstract class TasksEvent extends Equatable {
  const TasksEvent();

  @override
  List<Object?> get props => [];
}

class TasksLoadRequested extends TasksEvent {
  final int projectId;

  const TasksLoadRequested({required this.projectId});

  @override
  List<Object> get props => [projectId];
}

class TaskCreateRequested extends TasksEvent {
  final int projectId;
  final String title;
  final String description;
  final TaskComplexity complexity;
  final int? estimatedHours;
  final DateTime? dueDate;
  final List<String> tags;
  final List<Subtask> subtasks;

  const TaskCreateRequested({
    required this.projectId,
    required this.title,
    this.description = '',
    this.complexity = TaskComplexity.simple,
    this.estimatedHours,
    this.dueDate,
    this.tags = const [],
    this.subtasks = const [],
  });

  @override
  List<Object?> get props => [
        projectId,
        title,
        description,
        complexity,
        estimatedHours,
        dueDate,
        tags,
        subtasks,
      ];
}

class TaskUpdateRequested extends TasksEvent {
  final Task task;

  const TaskUpdateRequested(this.task);

  @override
  List<Object> get props => [task];
}

/// Guarda checklist (subtareas) u otros cambios sin pantalla de carga ni snackbar de éxito.
class TaskChecklistPersistRequested extends TasksEvent {
  final Task task;

  const TaskChecklistPersistRequested(this.task);

  @override
  List<Object> get props => [task];
}

class TaskDeleteRequested extends TasksEvent {
  final int id;
  final int projectId;

  const TaskDeleteRequested({required this.id, required this.projectId});

  @override
  List<Object> get props => [id, projectId];
}

class TaskStatusUpdateRequested extends TasksEvent {
  final int taskId;
  final TaskStatus status;
  final int projectId;

  const TaskStatusUpdateRequested({
    required this.taskId,
    required this.status,
    required this.projectId,
  });

  @override
  List<Object> get props => [taskId, status, projectId];
}

class TaskReorderRequested extends TasksEvent {
  final int taskId;
  final TaskStatus newStatus;
  final int targetIndex;
  final int projectId;

  const TaskReorderRequested({
    required this.taskId,
    required this.newStatus,
    required this.targetIndex,
    required this.projectId,
  });

  @override
  List<Object> get props => [taskId, newStatus, targetIndex, projectId];
}

// States
abstract class TasksState extends Equatable {
  const TasksState();

  @override
  List<Object?> get props => [];
}

class TasksInitial extends TasksState {}

class TasksLoading extends TasksState {}

class TasksLoaded extends TasksState {
  final List<Task> tasks;
  final int projectId;

  const TasksLoaded({required this.tasks, required this.projectId});

  @override
  List<Object> get props => [tasks, projectId];
}

class TasksFailure extends TasksState {
  final String message;

  const TasksFailure(this.message);

  @override
  List<Object> get props => [message];
}

class TaskOperationSuccess extends TasksState {
  final String message;

  const TaskOperationSuccess(this.message);

  @override
  List<Object> get props => [message];
}

// BLoC
class TasksBloc extends Bloc<TasksEvent, TasksState> {
  final TasksService tasksService;
  int? _currentProjectId;

  TasksBloc({required this.tasksService}) : super(TasksInitial()) {
    on<TasksLoadRequested>(_onTasksLoadRequested);
    on<TaskCreateRequested>(_onTaskCreateRequested);
    on<TaskUpdateRequested>(_onTaskUpdateRequested);
    on<TaskChecklistPersistRequested>(_onTaskChecklistPersistRequested);
    on<TaskDeleteRequested>(_onTaskDeleteRequested);
    on<TaskStatusUpdateRequested>(_onTaskStatusUpdateRequested);
    on<TaskReorderRequested>(_onTaskReorderRequested);
  }

  Future<void> _onTasksLoadRequested(
    TasksLoadRequested event,
    Emitter<TasksState> emit,
  ) async {
    _currentProjectId = event.projectId;
    emit(TasksLoading());
    
    try {
      final tasks = await tasksService.getTasksByProject(event.projectId);
      emit(TasksLoaded(tasks: tasks, projectId: event.projectId));
    } catch (e) {
      emit(TasksFailure('Error al cargar tareas: ${e.toString()}'));
    }
  }

  Future<void> _onTaskCreateRequested(
    TaskCreateRequested event,
    Emitter<TasksState> emit,
  ) async {
    emit(TasksLoading());
    
    try {
      await tasksService.createTask(
        projectId: event.projectId,
        title: event.title,
        description: event.description,
        complexity: event.complexity,
        estimatedHours: event.estimatedHours,
        dueDate: event.dueDate,
        tags: event.tags,
        subtasks: event.subtasks,
      );
      
      emit(const TaskOperationSuccess('Tarea creada correctamente'));
      add(TasksLoadRequested(projectId: event.projectId));
    } catch (e) {
      emit(TasksFailure('Error al crear tarea: ${e.toString()}'));
    }
  }

  Future<void> _onTaskUpdateRequested(
    TaskUpdateRequested event,
    Emitter<TasksState> emit,
  ) async {
    emit(TasksLoading());
    
    try {
      await tasksService.updateTask(event.task);
      
      emit(const TaskOperationSuccess('Tarea actualizada correctamente'));
      if (_currentProjectId != null) {
        add(TasksLoadRequested(projectId: _currentProjectId!));
      }
    } catch (e) {
      emit(TasksFailure('Error al actualizar tarea: ${e.toString()}'));
    }
  }

  Future<void> _onTaskChecklistPersistRequested(
    TaskChecklistPersistRequested event,
    Emitter<TasksState> emit,
  ) async {
    final task = event.task;
    final projectId = task.projectId;
    // No abortar si el estado es TaskOperationSuccess / TasksLoading / etc.:
    // antes se descartaba el evento y el checklist parecía no persistir nunca.
    if (_currentProjectId != null && _currentProjectId != projectId) {
      return;
    }

    try {
      final saved = await tasksService.updateTask(task);
      final s = state;
      if (s is TasksLoaded && s.projectId == projectId) {
        final newTasks =
            s.tasks.map((t) => t.id == saved.id ? saved : t).toList();
        emit(TasksLoaded(tasks: newTasks, projectId: s.projectId));
      } else {
        add(TasksLoadRequested(projectId: projectId));
      }
    } catch (e) {
      emit(TasksFailure('No se pudo guardar el checklist: ${e.toString()}'));
      add(TasksLoadRequested(projectId: projectId));
    }
  }

  Future<void> _onTaskDeleteRequested(
    TaskDeleteRequested event,
    Emitter<TasksState> emit,
  ) async {
    emit(TasksLoading());
    
    try {
      await tasksService.deleteTask(event.id);
      
      emit(const TaskOperationSuccess('Tarea eliminada correctamente'));
      add(TasksLoadRequested(projectId: event.projectId));
    } catch (e) {
      emit(TasksFailure('Error al eliminar tarea: ${e.toString()}'));
    }
  }

  Future<void> _onTaskStatusUpdateRequested(
    TaskStatusUpdateRequested event,
    Emitter<TasksState> emit,
  ) async {
    emit(TasksLoading());
    
    try {
      await tasksService.updateTaskStatus(event.taskId, event.status);
      
      emit(const TaskOperationSuccess('Estado actualizado'));
      add(TasksLoadRequested(projectId: event.projectId));
    } catch (e) {
      emit(TasksFailure('Error al actualizar estado: ${e.toString()}'));
    }
  }

  Future<void> _onTaskReorderRequested(
    TaskReorderRequested event,
    Emitter<TasksState> emit,
  ) async {
    // Actualización optimista - obtener estado actual
    final currentState = state;
    List<Task> originalTasks = [];
    
    if (currentState is TasksLoaded) {
      originalTasks = List.from(currentState.tasks);
    }
    
    try {
      await tasksService.moveTask(
        taskId: event.taskId,
        newStatus: event.newStatus,
        targetIndex: event.targetIndex,
      );
      
      // Recargar tareas
      add(TasksLoadRequested(projectId: event.projectId));
    } catch (e) {
      // Restaurar estado original en caso de error
      if (originalTasks.isNotEmpty) {
        emit(TasksLoaded(tasks: originalTasks, projectId: event.projectId));
      }
      emit(TasksFailure('Error al mover tarea: ${e.toString()}'));
    }
  }
}
