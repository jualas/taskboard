import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/project.dart';
import '../repositories/projects_repository.dart';

class UpdateProject implements UseCase<Project, Project> {
  UpdateProject(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<Project>> call(Project p) => _repo.updateProject(p);
}
