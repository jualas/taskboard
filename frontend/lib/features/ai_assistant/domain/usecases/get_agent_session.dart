import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/agent_session.dart';
import '../repositories/ai_assistant_repository.dart';

class GetAgentSession implements UseCase<AgentSession?, int> {
  GetAgentSession(this._repository);

  final AiAssistantRepository _repository;

  @override
  Future<Result<AgentSession?>> call(int projectId) =>
      _repository.getAgentSession(projectId);
}
