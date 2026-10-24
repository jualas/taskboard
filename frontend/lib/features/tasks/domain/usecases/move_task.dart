import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/task.dart';
import '../repositories/tasks_repository.dart';

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
