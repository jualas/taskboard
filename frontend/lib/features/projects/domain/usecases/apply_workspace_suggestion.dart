import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/projects_repository.dart';
import 'suggestion_action_params.dart';

class ApplyWorkspaceSuggestion
    implements UseCase<void, SuggestionActionParams> {
  ApplyWorkspaceSuggestion(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<void>> call(SuggestionActionParams p) =>
      _repo.applyWorkspaceSuggestion(p.projectId, p.suggestionId);
}
