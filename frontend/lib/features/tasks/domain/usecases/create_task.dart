import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/task.dart';
import '../repositories/tasks_repository.dart';

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
