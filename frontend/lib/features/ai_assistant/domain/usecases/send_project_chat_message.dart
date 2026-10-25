import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/ai_chat.dart';
import '../entities/ai_task_suggestion.dart';
import '../repositories/ai_assistant_repository.dart';

class SendProjectChatMessageParams {
  const SendProjectChatMessageParams({
    required this.projectTitle,
    required this.projectDescription,
    required this.messages,
    required this.draftTasks,
    this.projectId,
  });

  final String projectTitle;
  final String projectDescription;
  final List<AiChatMessage> messages;
  final List<AiTaskSuggestion> draftTasks;
  final int? projectId;
}

/// Turno del chat de planificación: historial + borrador actual.
class SendProjectChatMessage
    implements UseCase<AiChatReply, SendProjectChatMessageParams> {
  SendProjectChatMessage(this._repository);

  final AiAssistantRepository _repository;

  @override
  Future<Result<AiChatReply>> call(SendProjectChatMessageParams params) =>
      _repository.chatProjectPlan(
        projectTitle: params.projectTitle,
        projectDescription: params.projectDescription,
        messages: params.messages,
        draftTasks: params.draftTasks,
        projectId: params.projectId,
      );
}
