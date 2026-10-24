import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/task.dart';
import '../repositories/tasks_repository.dart';

class UpdateTask implements UseCase<Task, Task> {
  UpdateTask(this._repository);

  final TasksRepository _repository;

  @override
  Future<Result<Task>> call(Task params) => _repository.updateTask(params);
}
