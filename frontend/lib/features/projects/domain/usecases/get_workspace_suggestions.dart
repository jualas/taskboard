import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/workspace.dart';
import '../repositories/projects_repository.dart';

class GetWorkspaceSuggestions
    implements UseCase<List<WorkspaceSuggestion>, WorkspaceSuggestionsParams> {
  GetWorkspaceSuggestions(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<List<WorkspaceSuggestion>>> call(WorkspaceSuggestionsParams p) =>
      _repo.getWorkspaceSuggestions(p.projectId, state: p.state);
}

class WorkspaceSuggestionsParams {
  const WorkspaceSuggestionsParams(this.projectId, {this.state = 'pending'});
  final int projectId;
  final String state;
}
