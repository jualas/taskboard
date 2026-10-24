import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/project.dart';
import '../repositories/projects_repository.dart';

class CreateProject implements UseCase<Project, CreateProjectParams> {
  CreateProject(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<Project>> call(CreateProjectParams p) => _repo.createProject(
        Project.create(
          id: 0,
          title: p.title,
          description: p.description,
          status: p.status,
          workspacePath: p.workspacePath,
        ),
      );
}

class CreateProjectParams {
  const CreateProjectParams({
    required this.title,
    this.description = '',
    this.status = ProjectStatus.planning,
    this.workspacePath = '',
  });
  final String title;
  final String description;
  final ProjectStatus status;
  final String workspacePath;
}
