import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/ai_chat.dart';
import '../repositories/ai_assistant_repository.dart';

class SuggestProjectPlanParams {
  const SuggestProjectPlanParams({
    required this.projectTitle,
    required this.projectDescription,
    this.userMessage = '',
  });

  final String projectTitle;
  final String projectDescription;
  final String userMessage;
}

/// Primer plan de tareas de un proyecto nuevo.
class SuggestProjectPlan
    implements UseCase<AiSuggestionResult, SuggestProjectPlanParams> {
  SuggestProjectPlan(this._repository);

  final AiAssistantRepository _repository;

  @override
  Future<Result<AiSuggestionResult>> call(SuggestProjectPlanParams params) =>
      _repository.suggestProjectPlan(
        projectTitle: params.projectTitle,
        projectDescription: params.projectDescription,
        userMessage: params.userMessage.trim(),
      );
}
