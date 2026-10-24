import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/projects_repository.dart';

class DeleteProject implements UseCase<void, int> {
  DeleteProject(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<void>> call(int id) => _repo.deleteProject(id);
}
