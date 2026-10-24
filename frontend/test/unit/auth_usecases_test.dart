import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_taskboard/core/error/failures.dart';
import 'package:personal_taskboard/core/error/result.dart';
import 'package:personal_taskboard/core/usecase/usecase.dart';
import 'package:personal_taskboard/features/auth/domain/entities/auth_user.dart';
import 'package:personal_taskboard/features/auth/domain/repositories/auth_repository.dart';
import 'package:personal_taskboard/features/auth/domain/usecases/auth_usecases.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _user = AuthUser(id: 'u1', email: 'u@test.com');

void main() {
  late _MockAuthRepository repo;

  setUp(() => repo = _MockAuthRepository());

  test('Login recorta el email y delega en el repositorio', () async {
    when(
      () => repo.login(email: 'u@test.com', password: 'pw'),
    ).thenAnswer((_) async => const Success(_user));
    final result = await Login(repo)(
      const LoginParams(email: ' u@test.com ', password: 'pw'),
    );
    expect(result.valueOrNull, _user);
  });

  test('Login con campos vacíos falla sin llamar al repositorio', () async {
    final result = await Login(repo)(
      const LoginParams(email: '  ', password: 'pw'),
    );
    expect(result.failureOrNull, isA<ValidationFailure>());
    verifyNever(
      () => repo.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  test('Login propaga el fallo del repositorio', () async {
    when(
      () => repo.login(email: 'u@test.com', password: 'mal'),
    ).thenAnswer((_) async => const ResultFailure(UnauthorizedFailure()));
    final result = await Login(repo)(
      const LoginParams(email: 'u@test.com', password: 'mal'),
    );
    expect(result.failureOrNull, isA<UnauthorizedFailure>());
  });

  test('Logout delega en el repositorio', () async {
    when(() => repo.logout()).thenAnswer((_) async => const Success(null));
    expect((await Logout(repo)(const NoParams())).isSuccess, isTrue);
  });

  test('RestoreSession devuelve la sesión guardada', () async {
    when(
      () => repo.restoreSession(),
    ).thenAnswer((_) async => const Success(_user));
    final result = await RestoreSession(repo)(const NoParams());
    expect(result.valueOrNull, _user);
  });

  test('ChangePassword propaga el fallo', () async {
    when(
      () => repo.changePassword(currentPassword: 'a', newPassword: 'b'),
    ).thenAnswer(
      (_) async => const ResultFailure(
        UnauthorizedFailure('Contraseña actual incorrecta'),
      ),
    );
    final result = await ChangePassword(repo)(
      const ChangePasswordParams(currentPassword: 'a', newPassword: 'b'),
    );
    expect(result.failureOrNull?.message, 'Contraseña actual incorrecta');
  });
}
