import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/workspace.dart';
import '../repositories/projects_repository.dart';

class PreviewWorkspaceSnapshot implements UseCase<WorkspacePreview, String> {
  PreviewWorkspaceSnapshot(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<WorkspacePreview>> call(String path) =>
      _repo.previewWorkspaceSnapshot(path);
}
