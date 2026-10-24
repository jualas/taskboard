import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_taskboard/core/error/failures.dart';
import 'package:personal_taskboard/core/error/result.dart';
import 'package:personal_taskboard/core/usecase/usecase.dart';
import 'package:personal_taskboard/features/auth/domain/entities/auth_user.dart';
import 'package:personal_taskboard/features/auth/domain/usecases/auth_usecases.dart';
import 'package:personal_taskboard/features/auth/presentation/bloc/auth_bloc.dart';

class _MockRestoreSession extends Mock implements RestoreSession {}

class _MockLogin extends Mock implements Login {}

class _MockLogout extends Mock implements Logout {}

class _MockChangePassword extends Mock implements ChangePassword {}

const _user = AuthUser(id: 'u1', email: 'u@test.com');

void main() {
  late _MockRestoreSession restoreSession;
  late _MockLogin login;
  late _MockLogout logout;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const LoginParams(email: '', password: ''));
  });

  setUp(() {
    restoreSession = _MockRestoreSession();
    login = _MockLogin();
    logout = _MockLogout();
  });

  AuthBloc build() => AuthBloc(
    restoreSession: restoreSession,
    login: login,
    logout: logout,
    changePassword: _MockChangePassword(),
  );

  group('AuthBloc', () {
    test('initial state is AuthInitial', () {
      final bloc = build();
      expect(bloc.state, isA<AuthInitial>());
      bloc.close();
    });

    blocTest<AuthBloc, AuthState>(
      'AuthCheckRequested: authenticated',
      setUp: () => when(
        () => restoreSession(any()),
      ).thenAnswer((_) async => const Success(_user)),
      build: build,
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [
        isA<AuthLoading>(),
        const AuthAuthenticated(email: 'u@test.com'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthCheckRequested: not authenticated',
      setUp: () => when(
        () => restoreSession(any()),
      ).thenAnswer((_) async => const Success(null)),
      build: build,
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthLoginRequested: success',
      setUp: () => when(
        () => login(any()),
      ).thenAnswer((_) async => const Success(_user)),
      build: build,
      act: (bloc) => bloc.add(
        const AuthLoginRequested(email: 'u@test.com', password: 'x'),
      ),
      expect: () => [
        isA<AuthLoading>(),
        const AuthAuthenticated(email: 'u@test.com'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthLoginRequested: credenciales incorrectas',
      setUp: () => when(() => login(any())).thenAnswer(
        (_) async => const ResultFailure(
          UnauthorizedFailure('Credenciales incorrectas'),
        ),
      ),
      build: build,
      act: (bloc) => bloc.add(
        const AuthLoginRequested(email: 'u@test.com', password: 'mal'),
      ),
      expect: () => [
        isA<AuthLoading>(),
        const AuthFailure('Error al iniciar sesión: Credenciales incorrectas'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthLogoutRequested: success',
      setUp: () => when(
        () => logout(any()),
      ).thenAnswer((_) async => const Success(null)),
      build: build,
      act: (bloc) => bloc.add(AuthLogoutRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthLogoutRequested: failure',
      setUp: () => when(() => logout(any())).thenAnswer(
        (_) async => const ResultFailure(UnexpectedFailure('Logout failed')),
      ),
      build: build,
      act: (bloc) => bloc.add(AuthLogoutRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthFailure>()],
    );
  });
}
