import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/task.dart';
import '../repositories/tasks_repository.dart';

class GetTasksByProject
    implements UseCase<List<Task>, GetTasksByProjectParams> {
  GetTasksByProject(this._repository);

  final TasksRepository _repository;

  @override
  Future<Result<List<Task>>> call(GetTasksByProjectParams params) =>
      _repository.getTasksByProject(params.projectId);
}

class GetTasksByProjectParams {
  const GetTasksByProjectParams(this.projectId);
  final int projectId;
}

class CreateTask implements UseCase<Task, CreateTaskParams> {
  CreateTask(this._repository);

  final TasksRepository _repository;

  @override
  Future<Result<Task>> call(CreateTaskParams params) => _repository.createTask(
        projectId: params.projectId,
        title: params.title,
        description: params.description,
        status: params.status,
        dueDate: params.dueDate,
        estimatedHours: params.estimatedHours,
        complexity: params.complexity,
        tags: params.tags,
        subtasks: params.subtasks,
      );
}

class CreateTaskParams {
  const CreateTaskParams({
    required this.projectId,
    required this.title,
    this.description = '',
    this.status = TaskStatus.pending,
    this.dueDate,
    this.estimatedHours,
    this.complexity = TaskComplexity.simple,
    this.tags = const [],
    this.subtasks = const [],
  });

  final int projectId;
  final String title;
  final String description;
  final TaskStatus status;
  final DateTime? dueDate;
  final int? estimatedHours;
  final TaskComplexity complexity;
  final List<String> tags;
  final List<Subtask> subtasks;
}

class UpdateTask implements UseCase<Task, Task> {
  UpdateTask(this._repository);

  final TasksRepository _repository;

  @override
  Future<Result<Task>> call(Task params) => _repository.updateTask(params);
}

class DeleteTask implements UseCase<void, DeleteTaskParams> {
  DeleteTask(this._repository);

  final TasksRepository _repository;

  @override
  Future<Result<void>> call(DeleteTaskParams params) =>
      _repository.deleteTask(params.id);
}

class DeleteTaskParams {
  const DeleteTaskParams(this.id);
  final int id;
}

class UpdateTaskStatus implements UseCase<Task, UpdateTaskStatusParams> {
  UpdateTaskStatus(this._repository);

  final TasksRepository _repository;

  @override
  Future<Result<Task>> call(UpdateTaskStatusParams params) =>
      _repository.updateTaskStatus(params.taskId, params.status);
}

class UpdateTaskStatusParams {
  const UpdateTaskStatusParams({
    required this.taskId,
    required this.status,
  });

  final int taskId;
  final TaskStatus status;
}

class MoveTask implements UseCase<Task, MoveTaskParams> {
  MoveTask(this._repository);

  final TasksRepository _repository;

  @override
  Future<Result<Task>> call(MoveTaskParams params) => _repository.moveTask(
        taskId: params.taskId,
        newStatus: params.newStatus,
        targetIndex: params.targetIndex,
      );
}

class MoveTaskParams {
  const MoveTaskParams({
    required this.taskId,
    required this.newStatus,
    required this.targetIndex,
  });

  final int taskId;
  final TaskStatus newStatus;
  final int targetIndex;
}
