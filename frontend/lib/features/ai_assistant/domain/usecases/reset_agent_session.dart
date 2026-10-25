import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/ai_assistant_repository.dart';

class ResetAgentSession implements UseCase<void, int> {
  ResetAgentSession(this._repository);

  final AiAssistantRepository _repository;

  @override
  Future<Result<void>> call(int projectId) =>
      _repository.resetAgentSession(projectId);
}
