import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class RestoreSession implements UseCase<AuthUser?, NoParams> {
  RestoreSession(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthUser?>> call(NoParams params) =>
      _repository.restoreSession();
}
