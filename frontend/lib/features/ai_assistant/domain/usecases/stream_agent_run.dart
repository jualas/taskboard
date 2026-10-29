import '../../../../core/error/result.dart';
import '../entities/agent_session.dart';
import '../repositories/ai_assistant_repository.dart';

class StreamAgentRunParams {
  const StreamAgentRunParams({
    required this.prompt,
    this.projectId,
    this.projectTitle = '',
    this.projectDescription = '',
    this.execute = false,
    this.continueSession = true,
    this.newSession = false,
  });

  final String prompt;
  final int? projectId;
  final String projectTitle;
  final String projectDescription;
  final bool execute;
  final bool continueSession;
  final bool newSession;
}

/// Ejecución en vivo de Claude Code. Devuelve un stream, así que no
/// implementa `UseCase`.
class StreamAgentRun {
  StreamAgentRun(this._repository);

  final AiAssistantRepository _repository;

  Stream<Result<AgentStreamEvent>> call(StreamAgentRunParams params) =>
      _repository.streamAgentRun(
        prompt: params.prompt,
        projectId: params.projectId,
        projectTitle: params.projectTitle,
        projectDescription: params.projectDescription,
        execute: params.execute,
        continueSession: params.continueSession,
        newSession: params.newSession,
      );
}
