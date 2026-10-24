import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/projects_repository.dart';

class RemoveProjectMember implements UseCase<void, MemberRemoveParams> {
  RemoveProjectMember(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<void>> call(MemberRemoveParams p) =>
      _repo.removeProjectMember(projectId: p.projectId, userId: p.userId);
}

class MemberRemoveParams {
  const MemberRemoveParams({required this.projectId, required this.userId});
  final int projectId;
  final String userId;
}
