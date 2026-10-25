import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/agent_session.dart';
import '../repositories/ai_assistant_repository.dart';

class GetAgentRuns implements UseCase<List<AgentRun>, int> {
  GetAgentRuns(this._repository);

  final AiAssistantRepository _repository;

  @override
  Future<Result<List<AgentRun>>> call(int projectId) =>
      _repository.getAgentRuns(projectId);
}
