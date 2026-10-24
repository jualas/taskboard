import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/workspace.dart';
import '../repositories/projects_repository.dart';

class GetWorkspaceInventory implements UseCase<WorkspaceInventory, NoParams> {
  GetWorkspaceInventory(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<WorkspaceInventory>> call(NoParams params) =>
      _repo.getWorkspaceInventory();
}
