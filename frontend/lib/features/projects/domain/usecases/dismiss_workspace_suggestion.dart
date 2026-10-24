import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/projects_repository.dart';
import 'suggestion_action_params.dart';

class DismissWorkspaceSuggestion implements UseCase<void, SuggestionActionParams> {
  DismissWorkspaceSuggestion(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<void>> call(SuggestionActionParams p) =>
      _repo.dismissWorkspaceSuggestion(p.projectId, p.suggestionId);
}
