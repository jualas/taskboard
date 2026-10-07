import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';

import 'package:personal_taskboard/blocs/auth_bloc.dart';
import 'package:personal_taskboard/services/auth_service.dart';

class _FakeAuth implements AuthService {
  _FakeAuth({
    this.authenticated = false,
    this.email,
    this.logoutThrows = false,
  });

  bool authenticated;
  String? email;
  bool logoutThrows;

  @override
  bool get isAuthenticated => authenticated;

  @override
  String? get currentUserEmail => email;

  @override
  String? get currentUserId => null;

  @override
  String? get currentUserName => null;

  @override
  Future<void> init() async {}

  @override
  Future<bool> login(String e, String p) async {
    authenticated = true;
    email = e;
    return true;
  }

  @override
  Future<void> logout() async {
    if (logoutThrows) throw Exception('Logout failed');
    authenticated = false;
    email = null;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<bool> validateCredentials(String e, String p) => login(e, p);
}

void main() {
  group('AuthBloc', () {
    test('initial state is AuthInitial', () {
      final bloc = AuthBloc(authService: _FakeAuth());
      expect(bloc.state, isA<AuthInitial>());
      bloc.close();
    });

    blocTest<AuthBloc, AuthState>(
      'AuthCheckRequested: authenticated',
      build: () => AuthBloc(
        authService: _FakeAuth(authenticated: true, email: 'u@test.com'),
      ),
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [
        isA<AuthLoading>(),
        const AuthAuthenticated(email: 'u@test.com'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthCheckRequested: not authenticated',
      build: () => AuthBloc(authService: _FakeAuth()),
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthLogoutRequested: success',
      build: () => AuthBloc(
        authService: _FakeAuth(authenticated: true, email: 'a@b.c'),
      ),
      act: (bloc) => bloc.add(AuthLogoutRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthLogoutRequested: failure',
      build: () => AuthBloc(
        authService: _FakeAuth(
          authenticated: true,
          logoutThrows: true,
        ),
      ),
      act: (bloc) => bloc.add(AuthLogoutRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthFailure>()],
    );
  });
}
