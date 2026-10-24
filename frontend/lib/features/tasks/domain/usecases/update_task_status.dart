import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/task.dart';
import '../repositories/tasks_repository.dart';

class UpdateTaskStatusParams {
  const UpdateTaskStatusParams({
    required this.taskId,
    required this.status,
  });

  final int taskId;
  final TaskStatus status;
}

class UpdateTaskStatus implements UseCase<Task, UpdateTaskStatusParams> {
  UpdateTaskStatus(this._repository);

  final TasksRepository _repository;

  @override
  Future<Result<Task>> call(UpdateTaskStatusParams params) =>
      _repository.updateTaskStatus(params.taskId, params.status);
}
