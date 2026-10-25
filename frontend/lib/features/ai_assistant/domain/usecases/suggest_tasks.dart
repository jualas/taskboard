import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/ai_chat.dart';
import '../repositories/ai_assistant_repository.dart';

class SuggestTasksParams {
  const SuggestTasksParams({
    required this.userMessage,
    required this.projectTitle,
    required this.projectDescription,
  });

  final String userMessage;
  final String projectTitle;
  final String projectDescription;
}

/// «Sugerir con IA» del formulario de tarea.
class SuggestTasks implements UseCase<AiSuggestionResult, SuggestTasksParams> {
  SuggestTasks(this._repository);

  final AiAssistantRepository _repository;

  @override
  Future<Result<AiSuggestionResult>> call(SuggestTasksParams params) =>
      _repository.suggestTasks(
        userMessage: params.userMessage,
        projectTitle: params.projectTitle,
        projectDescription: params.projectDescription,
      );
}
