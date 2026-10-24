import '../../../../core/error/exception_to_failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/tasks_repository.dart';
import '../datasources/tasks_remote_data_source.dart';
import '../models/task_model.dart';

class TasksRepositoryImpl implements TasksRepository {
  TasksRepositoryImpl(this._remote);

  final TasksRemoteDataSource _remote;

  @override
  Future<Result<List<Task>>> getTasksByProject(int projectId) async {
    try {
      final models = await _remote.getTasksByProject(projectId);
      return Success(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<Task?>> getTask(int id) async {
    try {
      final model = await _remote.getTask(id);
      return Success(model?.toEntity());
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<Task>> createTask({
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
    try {
      final id = await _remote.getNextTaskId();
      final projectResult = await getTasksByProject(projectId);
      final projectTasks = projectResult.valueOrNull ?? [];
      final sameStatus =
          projectTasks.where((t) => t.status == status).toList();
      final kanbanPosition = sameStatus.isEmpty
          ? 1.0
          : sameStatus
                  .map((t) => t.kanbanPosition)
                  .reduce((a, b) => a > b ? a : b) +
              1;

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
      final saved = await _remote.saveTask(TaskModel.fromEntity(task));
      return Success(saved.toEntity());
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<Task>> updateTask(Task task) async {
    try {
      final saved =
          await _remote.saveTask(TaskModel.fromEntity(task));
      return Success(saved.toEntity());
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<void>> deleteTask(int id) async {
    try {
      await _remote.deleteTask(id);
      return const Success(null);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<Task>> updateTaskStatus(int id, TaskStatus status) async {
    try {
      final current = await _remote.getTask(id);
      if (current == null) {
        return const ResultFailure(NotFoundFailure('Tarea no encontrada'));
      }
      final task = current.toEntity();
      final projectResult = await getTasksByProject(task.projectId);
      final projectTasks = projectResult.valueOrNull ?? [];
      final sameStatus = projectTasks
          .where((t) => t.status == status && t.id != id)
          .toList();
      final kanbanPosition = sameStatus.isEmpty
          ? 1.0
          : sameStatus
                  .map((t) => t.kanbanPosition)
                  .reduce((a, b) => a > b ? a : b) +
              1;

      final updated = task.copyWith(
        status: status,
        kanbanPosition: kanbanPosition,
        updatedAt: DateTime.now(),
      );
      final saved = await _remote.saveTask(TaskModel.fromEntity(updated));
      return Success(saved.toEntity());
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<Task>> moveTask({
    required int taskId,
    required TaskStatus newStatus,
    required int targetIndex,
  }) async {
    try {
      final current = await _remote.getTask(taskId);
      if (current == null) {
        return const ResultFailure(NotFoundFailure('Tarea no encontrada'));
      }
      final task = current.toEntity();
      final projectResult = await getTasksByProject(task.projectId);
      final projectTasks = projectResult.valueOrNull ?? [];

      final targetColumnTasks = projectTasks
          .where((t) => t.status == newStatus && t.id != taskId)
          .toList()
        ..sort(compareTasksByKanbanPosition);

      double newPosition;
      if (targetColumnTasks.isEmpty) {
        newPosition = 1.0;
      } else if (targetIndex <= 0) {
        newPosition = targetColumnTasks.first.kanbanPosition / 2;
      } else if (targetIndex >= targetColumnTasks.length) {
        newPosition = targetColumnTasks.last.kanbanPosition + 1;
      } else {
        final prev = targetColumnTasks[targetIndex - 1].kanbanPosition;
        final next = targetColumnTasks[targetIndex].kanbanPosition;
        newPosition = (prev + next) / 2;
      }

      final updated = task.copyWith(
        status: newStatus,
        kanbanPosition: newPosition,
        updatedAt: DateTime.now(),
      );
      final saved = await _remote.saveTask(TaskModel.fromEntity(updated));
      return Success(saved.toEntity());
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }
}
