import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/project_member.dart';
import '../repositories/projects_repository.dart';
import 'member_change_params.dart';

class UpdateProjectMemberRole
    implements UseCase<ProjectMember, MemberChangeParams> {
  UpdateProjectMemberRole(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<ProjectMember>> call(MemberChangeParams p) =>
      _repo.updateProjectMemberRole(
        projectId: p.projectId,
        userId: p.userId,
        role: p.role,
      );
}
