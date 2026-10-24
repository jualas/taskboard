import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class LoginParams {
  const LoginParams({required this.email, required this.password});

  final String email;
  final String password;
}

class Login implements UseCase<AuthUser, LoginParams> {
  Login(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthUser>> call(LoginParams params) async {
    final email = params.email.trim();
    if (email.isEmpty || params.password.isEmpty) {
      return const ResultFailure(
        ValidationFailure('Introduce email y contraseña'),
      );
    }
    return _repository.login(email: email, password: params.password);
  }
}
