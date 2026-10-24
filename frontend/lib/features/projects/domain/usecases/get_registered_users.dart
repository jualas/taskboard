import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/workspace.dart';
import '../repositories/projects_repository.dart';

class GetRegisteredUsers implements UseCase<List<AppUser>, NoParams> {
  GetRegisteredUsers(this._repo);
  final ProjectsRepository _repo;
  @override
  Future<Result<List<AppUser>>> call(NoParams params) =>
      _repo.getRegisteredUsers();
}
