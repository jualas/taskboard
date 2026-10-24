import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/task.dart';
import '../repositories/tasks_repository.dart';

class GetTasksByProjectParams {
  const GetTasksByProjectParams(this.projectId);
  final int projectId;
}

class GetTasksByProject
    implements UseCase<List<Task>, GetTasksByProjectParams> {
  GetTasksByProject(this._repository);

  final TasksRepository _repository;

  @override
  Future<Result<List<Task>>> call(GetTasksByProjectParams params) async {
    final result = await _repository.getTasksByProject(params.projectId);
    return result.when(
      success: (tasks) {
        final sorted = List<Task>.of(tasks)
          ..sort(compareTasksByKanbanPosition);
        return Success(sorted);
      },
      onFailure: ResultFailure<List<Task>>.new,
    );
  }
}
