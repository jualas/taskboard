import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:frontend/blocs/auth_bloc.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/models/user.dart';

// Generar mocks
@GenerateMocks([AuthService])
import 'auth_bloc_test.mocks.dart';

void main() {
  group('AuthBloc', () {
    late MockAuthService mockAuthService;
    late AuthBloc authBloc;

    final tUser = User(
      id: 1,
      email: 'test@test.com',
      fullName: 'Test User',
      role: UserRole.student,
      status: UserStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() {
      mockAuthService = MockAuthService();
      authBloc = AuthBloc(authService: mockAuthService);
    });

    tearDown(() {
      authBloc.close();
    });

    test('initial state is AuthInitial', () {
      expect(authBloc.state, isA<AuthInitial>());
    });

    group('AuthCheckRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthAuthenticated] when session is valid',
        build: () {
          when(
            mockAuthService.getCurrentUserFromSupabase(),
          ).thenAnswer((_) async => tUser);
          return authBloc;
        },
        act: (bloc) => bloc.add(AuthCheckRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [isA<AuthLoading>(), AuthAuthenticated(tUser)],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthUnauthenticated] when there is no session',
        build: () {
          when(
            mockAuthService.getCurrentUserFromSupabase(),
          ).thenAnswer((_) async => null);
          return authBloc;
        },
        act: (bloc) => bloc.add(AuthCheckRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [isA<AuthLoading>(), AuthUnauthenticated()],
      );
    });

    group('AuthLogoutRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthUnauthenticated] when logout is successful',
        build: () {
          when(mockAuthService.signOut()).thenAnswer((_) async {});
          return authBloc;
        },
        act: (bloc) => bloc.add(AuthLogoutRequested()),
        expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
        verify: (_) {
          verify(mockAuthService.signOut()).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthFailure] when logout fails',
        build: () {
          when(mockAuthService.signOut()).thenThrow(Exception('Logout failed'));
          return authBloc;
        },
        act: (bloc) => bloc.add(AuthLogoutRequested()),
        expect: () => [isA<AuthLoading>(), isA<AuthFailure>()],
        verify: (_) {
          verify(mockAuthService.signOut()).called(1);
        },
      );
    });

    // Nota: Los tests de AuthLoginRequested requieren un BuildContext real
    // y son más complejos de mockear debido a la navegación y creación de usuario.
    // Se recomienda testearlos como tests de integración o widget tests.
  });
}
