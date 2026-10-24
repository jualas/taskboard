import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/project.dart';
import '../repositories/projects_repository.dart';

class GetProjects implements UseCase<List<Project>, NoParams> {
  GetProjects(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<List<Project>>> call(NoParams params) => _repo.getProjects();
}
