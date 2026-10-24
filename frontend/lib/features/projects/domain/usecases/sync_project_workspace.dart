import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/projects_repository.dart';

class SyncProjectWorkspace implements UseCase<void, int> {
  SyncProjectWorkspace(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<void>> call(int projectId) =>
      _repo.syncProjectWorkspace(projectId);
}
