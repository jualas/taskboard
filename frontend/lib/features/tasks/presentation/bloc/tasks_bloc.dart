import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/tasks_usecases.dart';

abstract class TasksEvent extends Equatable {
  const TasksEvent();

  @override
  List<Object?> get props => [];
}

class TasksLoadRequested extends TasksEvent {
  const TasksLoadRequested({required this.projectId});

  final int projectId;

  @override
  List<Object> get props => [projectId];
}

class TaskCreateRequested extends TasksEvent {
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

  final int projectId;
  final String title;
  final String description;
  final TaskComplexity complexity;
  final int? estimatedHours;
  final DateTime? dueDate;
  final List<String> tags;
  final List<Subtask> subtasks;

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
  const TaskUpdateRequested(this.task);

  final Task task;

  @override
  List<Object> get props => [task];
}

class TaskChecklistPersistRequested extends TasksEvent {
  const TaskChecklistPersistRequested(this.task);

  final Task task;

  @override
  List<Object> get props => [task];
}

class TaskDeleteRequested extends TasksEvent {
  const TaskDeleteRequested({required this.id, required this.projectId});

  final int id;
  final int projectId;

  @override
  List<Object> get props => [id, projectId];
}

class TaskStatusUpdateRequested extends TasksEvent {
  const TaskStatusUpdateRequested({
    required this.taskId,
    required this.status,
    required this.projectId,
  });

  final int taskId;
  final TaskStatus status;
  final int projectId;

  @override
  List<Object> get props => [taskId, status, projectId];
}

class TaskReorderRequested extends TasksEvent {
  const TaskReorderRequested({
    required this.taskId,
    required this.newStatus,
    required this.targetIndex,
    required this.projectId,
  });

  final int taskId;
  final TaskStatus newStatus;
  final int targetIndex;
  final int projectId;

  @override
  List<Object> get props => [taskId, newStatus, targetIndex, projectId];
}

abstract class TasksState extends Equatable {
  const TasksState();

  @override
  List<Object?> get props => [];
}

class TasksInitial extends TasksState {}

class TasksLoading extends TasksState {}

class TasksLoaded extends TasksState {
  const TasksLoaded({required this.tasks, required this.projectId});

  final List<Task> tasks;
  final int projectId;

  @override
  List<Object> get props => [tasks, projectId];
}

class TasksFailure extends TasksState {
  const TasksFailure(this.message);

  final String message;

  @override
  List<Object> get props => [message];
}

class TaskOperationSuccess extends TasksState {
  const TaskOperationSuccess(this.message);

  final String message;

  @override
  List<Object> get props => [message];
}

class TasksBloc extends Bloc<TasksEvent, TasksState> {
  TasksBloc({
    required GetTasksByProject getTasksByProject,
    required CreateTask createTask,
    required UpdateTask updateTask,
    required DeleteTask deleteTask,
    required UpdateTaskStatus updateTaskStatus,
    required MoveTask moveTask,
  })  : _getTasksByProject = getTasksByProject,
        _createTask = createTask,
        _updateTask = updateTask,
        _deleteTask = deleteTask,
        _updateTaskStatus = updateTaskStatus,
        _moveTask = moveTask,
        super(TasksInitial()) {
    on<TasksLoadRequested>(_onTasksLoadRequested);
    on<TaskCreateRequested>(_onTaskCreateRequested);
    on<TaskUpdateRequested>(_onTaskUpdateRequested);
    on<TaskChecklistPersistRequested>(_onTaskChecklistPersistRequested);
    on<TaskDeleteRequested>(_onTaskDeleteRequested);
    on<TaskStatusUpdateRequested>(_onTaskStatusUpdateRequested);
    on<TaskReorderRequested>(_onTaskReorderRequested);
  }

  final GetTasksByProject _getTasksByProject;
  final CreateTask _createTask;
  final UpdateTask _updateTask;
  final DeleteTask _deleteTask;
  final UpdateTaskStatus _updateTaskStatus;
  final MoveTask _moveTask;

  int? _currentProjectId;

  String _failureMessage(Result<dynamic> result, String prefix) {
    return '$prefix: ${result.failureOrNull?.message ?? 'error desconocido'}';
  }

  Future<void> _onTasksLoadRequested(
    TasksLoadRequested event,
    Emitter<TasksState> emit,
  ) async {
    _currentProjectId = event.projectId;
    emit(TasksLoading());

    final result =
        await _getTasksByProject(GetTasksByProjectParams(event.projectId));
    result.when(
      success: (tasks) =>
          emit(TasksLoaded(tasks: tasks, projectId: event.projectId)),
      onFailure: (f) => emit(TasksFailure('Error al cargar tareas: ${f.message}')),
    );
  }

  Future<void> _onTaskCreateRequested(
    TaskCreateRequested event,
    Emitter<TasksState> emit,
  ) async {
    emit(TasksLoading());

    final result = await _createTask(
      CreateTaskParams(
        projectId: event.projectId,
        title: event.title,
        description: event.description,
        complexity: event.complexity,
        estimatedHours: event.estimatedHours,
        dueDate: event.dueDate,
        tags: event.tags,
        subtasks: event.subtasks,
      ),
    );

    if (result.isFailure) {
      emit(TasksFailure(_failureMessage(result, 'Error al crear tarea')));
      return;
    }
    emit(const TaskOperationSuccess('Tarea creada correctamente'));
    add(TasksLoadRequested(projectId: event.projectId));
  }

  Future<void> _onTaskUpdateRequested(
    TaskUpdateRequested event,
    Emitter<TasksState> emit,
  ) async {
    emit(TasksLoading());

    final result = await _updateTask(event.task);
    if (result.isFailure) {
      emit(TasksFailure(_failureMessage(result, 'Error al actualizar tarea')));
      return;
    }
    emit(const TaskOperationSuccess('Tarea actualizada correctamente'));
    if (_currentProjectId != null) {
      add(TasksLoadRequested(projectId: _currentProjectId!));
    }
  }

  Future<void> _onTaskChecklistPersistRequested(
    TaskChecklistPersistRequested event,
    Emitter<TasksState> emit,
  ) async {
    final task = event.task;
    final projectId = task.projectId;
    if (_currentProjectId != null && _currentProjectId != projectId) {
      return;
    }

    final result = await _updateTask(task);
    if (result.isFailure) {
      emit(TasksFailure(
        _failureMessage(result, 'No se pudo guardar el checklist'),
      ));
      add(TasksLoadRequested(projectId: projectId));
      return;
    }

    final saved = result.valueOrNull!;
    final s = state;
    if (s is TasksLoaded && s.projectId == projectId) {
      final newTasks =
          s.tasks.map((t) => t.id == saved.id ? saved : t).toList();
      emit(TasksLoaded(tasks: newTasks, projectId: s.projectId));
    } else {
      add(TasksLoadRequested(projectId: projectId));
    }
  }

  Future<void> _onTaskDeleteRequested(
    TaskDeleteRequested event,
    Emitter<TasksState> emit,
  ) async {
    emit(TasksLoading());

    final result = await _deleteTask(DeleteTaskParams(event.id));
    if (result.isFailure) {
      emit(TasksFailure(_failureMessage(result, 'Error al eliminar tarea')));
      return;
    }
    emit(const TaskOperationSuccess('Tarea eliminada correctamente'));
    add(TasksLoadRequested(projectId: event.projectId));
  }

  Future<void> _onTaskStatusUpdateRequested(
    TaskStatusUpdateRequested event,
    Emitter<TasksState> emit,
  ) async {
    emit(TasksLoading());

    final result = await _updateTaskStatus(
      UpdateTaskStatusParams(taskId: event.taskId, status: event.status),
    );
    if (result.isFailure) {
      emit(TasksFailure(_failureMessage(result, 'Error al actualizar estado')));
      return;
    }
    emit(const TaskOperationSuccess('Estado actualizado'));
    add(TasksLoadRequested(projectId: event.projectId));
  }

  Future<void> _onTaskReorderRequested(
    TaskReorderRequested event,
    Emitter<TasksState> emit,
  ) async {
    final currentState = state;
    List<Task> originalTasks = [];

    if (currentState is TasksLoaded) {
      originalTasks = List.from(currentState.tasks);
    }

    final result = await _moveTask(
      MoveTaskParams(
        taskId: event.taskId,
        newStatus: event.newStatus,
        targetIndex: event.targetIndex,
      ),
    );

    if (result.isFailure) {
      if (originalTasks.isNotEmpty) {
        emit(TasksLoaded(tasks: originalTasks, projectId: event.projectId));
      }
      emit(TasksFailure(_failureMessage(result, 'Error al mover tarea')));
      return;
    }
    add(TasksLoadRequested(projectId: event.projectId));
  }
}
