import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/workspace.dart';
import '../repositories/projects_repository.dart';

class PrepareIdeSession implements UseCase<IdePrompt, PrepareIdeSessionParams> {
  PrepareIdeSession(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<IdePrompt>> call(PrepareIdeSessionParams p) =>
      _repo.prepareIdeSession(p.projectId, focusTaskId: p.focusTaskId);
}

class PrepareIdeSessionParams {
  const PrepareIdeSessionParams({required this.projectId, this.focusTaskId});
  final int projectId;
  final int? focusTaskId;
}
