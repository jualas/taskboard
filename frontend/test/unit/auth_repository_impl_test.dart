import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_taskboard/core/error/exceptions.dart';
import 'package:personal_taskboard/core/error/failures.dart';
import 'package:personal_taskboard/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:personal_taskboard/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:personal_taskboard/features/auth/data/models/auth_session_model.dart';
import 'package:personal_taskboard/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:personal_taskboard/features/auth/domain/entities/auth_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

const _apiSession = AuthSessionModel(
  userId: 'u1',
  accessToken: 'jwt',
  email: 'u@test.com',
);

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  group('modo API', () {
    late _MockRemote remote;
    late AuthLocalDataSourceImpl local;
    late AuthRepositoryImpl repo;

    setUp(() async {
      remote = _MockRemote();
      local = AuthLocalDataSourceImpl(await _prefs());
      repo = AuthRepositoryImpl(local: local, remote: remote);
    });

    test('login guarda el token y emite el usuario', () async {
      when(
        () => remote.login('u@test.com', 'pw'),
      ).thenAnswer((_) async => _apiSession);
      final emitted = expectLater(
        repo.sessionChanges,
        emits(const AuthUser(id: 'u1', email: 'u@test.com')),
      );

      final result = await repo.login(email: 'u@test.com', password: 'pw');

      expect(result.valueOrNull?.id, 'u1');
      expect(local.accessToken, 'jwt');
      expect(repo.currentUser?.email, 'u@test.com');
      await emitted;
    });

    test(
      'login con 401 devuelve UnauthorizedFailure y no guarda nada',
      () async {
        when(
          () => remote.login(any(), any()),
        ).thenThrow(const UnauthorizedException('Credenciales incorrectas'));
        final result = await repo.login(email: 'u@test.com', password: 'mal');
        expect(result.failureOrNull, isA<UnauthorizedFailure>());
        expect(result.failureOrNull?.message, 'Credenciales incorrectas');
        expect(local.accessToken, isNull);
        expect(repo.currentUser, isNull);
      },
    );

    test('restoreSession recupera la sesión guardada al recargar', () async {
      final prefs = await _prefs({
        'taskboard_api_access_token': 'jwt',
        'taskboard_api_user_email': 'u@test.com',
        'taskboard_api_user_id': 'u1',
      });
      final repo = AuthRepositoryImpl(
        local: AuthLocalDataSourceImpl(prefs),
        remote: remote,
      );
      final result = await repo.restoreSession();
      expect(result.valueOrNull, const AuthUser(id: 'u1', email: 'u@test.com'));
      expect(repo.currentUser, isNotNull);
    });

    test('restoreSession sin usuario guardado no abre sesión', () async {
      final prefs = await _prefs({'taskboard_api_access_token': 'jwt'});
      final repo = AuthRepositoryImpl(
        local: AuthLocalDataSourceImpl(prefs),
        remote: remote,
      );
      expect((await repo.restoreSession()).valueOrNull, isNull);
    });

    test('logout borra la sesión y emite null', () async {
      when(
        () => remote.login(any(), any()),
      ).thenAnswer((_) async => _apiSession);
      await repo.login(email: 'u@test.com', password: 'pw');
      final emitted = expectLater(repo.sessionChanges, emits(isNull));

      final result = await repo.logout();

      expect(result.isSuccess, isTrue);
      expect(local.accessToken, isNull);
      expect(local.readSession(), isNull);
      expect(repo.currentUser, isNull);
      await emitted;
    });

    test('changePassword envía el token guardado', () async {
      when(
        () => remote.login(any(), any()),
      ).thenAnswer((_) async => _apiSession);
      when(
        () => remote.changePassword(
          accessToken: 'jwt',
          currentPassword: 'a',
          newPassword: 'b',
        ),
      ).thenAnswer((_) async {});
      await repo.login(email: 'u@test.com', password: 'pw');

      final result = await repo.changePassword(
        currentPassword: 'a',
        newPassword: 'b',
      );
      expect(result.isSuccess, isTrue);
    });

    test('changePassword sin sesión devuelve UnauthorizedFailure', () async {
      final result = await repo.changePassword(
        currentPassword: 'a',
        newPassword: 'b',
      );
      expect(result.failureOrNull, isA<UnauthorizedFailure>());
    });

    test('changePassword con token caducado (401) devuelve el fallo', () async {
      when(
        () => remote.login(any(), any()),
      ).thenAnswer((_) async => _apiSession);
      when(
        () => remote.changePassword(
          accessToken: any(named: 'accessToken'),
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenThrow(const UnauthorizedException('Contraseña actual incorrecta'));
      await repo.login(email: 'u@test.com', password: 'pw');

      final result = await repo.changePassword(
        currentPassword: 'a',
        newPassword: 'b',
      );
      expect(result.failureOrNull, isA<UnauthorizedFailure>());
    });
  });

  group('modo local', () {
    late DemoAuthLocalDataSource local;
    late AuthRepositoryImpl repo;

    setUp(() async {
      local = DemoAuthLocalDataSource(await _prefs());
      repo = AuthRepositoryImpl(local: local);
    });

    test('login abre sesión local sin token', () async {
      final result = await repo.login(email: 'yo@local', password: 'x');
      expect(
        result.valueOrNull,
        const AuthUser(
          id: 'local-user',
          email: 'yo@local',
          name: 'Usuario local',
        ),
      );
      expect(local.accessToken, isNull);
    });

    test('restoreSession recupera la sesión local', () async {
      final prefs = await _prefs({
        'taskboard_local_demo_auth': true,
        'taskboard_local_demo_email': 'yo@local',
      });
      final repo = AuthRepositoryImpl(local: DemoAuthLocalDataSource(prefs));
      expect((await repo.restoreSession()).valueOrNull?.email, 'yo@local');
    });

    test('logout cierra la sesión local', () async {
      await repo.login(email: 'yo@local', password: 'x');
      await repo.logout();
      expect(local.readSession(), isNull);
      expect(repo.currentUser, isNull);
    });

    test('changePassword no está soportado', () async {
      final result = await repo.changePassword(
        currentPassword: 'a',
        newPassword: 'b',
      );
      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
