import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/project.dart';
import '../repositories/projects_repository.dart';

class GetProject implements UseCase<Project?, int> {
  GetProject(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<Project?>> call(int id) => _repo.getProject(id);
}
