import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/project_member.dart';
import '../repositories/projects_repository.dart';
import 'member_change_params.dart';

class AddProjectMember implements UseCase<ProjectMember, MemberChangeParams> {
  AddProjectMember(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<ProjectMember>> call(MemberChangeParams p) =>
      _repo.addProjectMember(
        projectId: p.projectId,
        userId: p.userId,
        role: p.role,
      );
}
