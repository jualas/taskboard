import '../../../../core/error/result.dart';
import '../entities/agent_session.dart';
import '../entities/ai_chat.dart';
import '../entities/ai_task_suggestion.dart';

abstract class AiAssistantRepository {
  Future<Result<AiSuggestionResult>> suggestTasks({
    required String userMessage,
    required String projectTitle,
    required String projectDescription,
  });

  Future<Result<AiSuggestionResult>> suggestProjectPlan({
    required String projectTitle,
    required String projectDescription,
    String userMessage = '',
  });

  /// El título y la descripción del proyecto viajan como datos en
  /// `projectContext`, nunca mezclados con las instrucciones.
  Future<Result<AiChatReply>> chatProjectPlan({
    required String projectTitle,
    required String projectDescription,
    required List<AiChatMessage> messages,
    required List<AiTaskSuggestion> draftTasks,
    int? projectId,
  });

  /// Cada evento llega como `Success`; un error corta el stream con un único
  /// `ResultFailure`.
  Stream<Result<AgentStreamEvent>> streamAgentRun({
    required String prompt,
    int? projectId,
    String projectTitle = '',
    String projectDescription = '',
    bool execute = false,
    bool continueSession = true,
    bool newSession = false,
  });

  Future<Result<AgentSession?>> getAgentSession(int projectId);

  Future<Result<void>> resetAgentSession(int projectId);

  Future<Result<List<AgentRun>>> getAgentRuns(int projectId, {int limit = 30});
}
