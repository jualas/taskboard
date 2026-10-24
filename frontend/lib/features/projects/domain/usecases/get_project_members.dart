import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/project_member.dart';
import '../repositories/projects_repository.dart';

class GetProjectMembers implements UseCase<List<ProjectMember>, int> {
  GetProjectMembers(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<List<ProjectMember>>> call(int projectId) =>
      _repo.getProjectMembers(projectId);
}
