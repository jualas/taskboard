import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/tasks_repository.dart';

class DeleteTaskParams {
  const DeleteTaskParams(this.id);
  final int id;
}

class DeleteTask implements UseCase<void, DeleteTaskParams> {
  DeleteTask(this._repository);

  final TasksRepository _repository;

  @override
  Future<Result<void>> call(DeleteTaskParams params) =>
      _repository.deleteTask(params.id);
}
