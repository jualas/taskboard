import 'dart:async';

import '../../../../core/error/exception_to_failure.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_session_model.dart';

/// Con `remote` valida contra el API; sin él es el modo local de demostración
/// y cualquier email/contraseña no vacíos abren sesión.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthLocalDataSource local,
    AuthRemoteDataSource? remote,
  }) : _local = local,
       _remote = remote;

  final AuthLocalDataSource _local;
  final AuthRemoteDataSource? _remote;
  final _changes = StreamController<AuthUser?>.broadcast();

  AuthUser? _current;

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> get sessionChanges => _changes.stream;

  void _setCurrent(AuthUser? user) {
    _current = user;
    _changes.add(user);
  }

  @override
  Future<Result<AuthUser?>> restoreSession() async {
    try {
      _current = _local.readSession()?.toEntity();
      return Success(_current);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<AuthUser>> login({
    required String email,
    required String password,
  }) async {
    try {
      final remote = _remote;
      final session = remote == null
          ? AuthSessionModel(userId: '', email: email)
          : await remote.login(email, password);
      await _local.saveSession(session);
      final user = _local.readSession()?.toEntity() ?? session.toEntity();
      _setCurrent(user);
      return Success(user);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await _local.clearSession();
      _setCurrent(null);
      return const Success(null);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final remote = _remote;
    if (remote == null) {
      return const ResultFailure(
        UnexpectedFailure('El modo local no soporta cambio de contraseña'),
      );
    }
    final token = _local.accessToken;
    if (token == null || token.isEmpty) {
      return const ResultFailure(
        UnauthorizedFailure('No hay sesión. Inicia sesión de nuevo.'),
      );
    }
    try {
      await remote.changePassword(
        accessToken: token,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return const Success(null);
    } catch (e) {
      return ResultFailure(mapExceptionToFailure(e));
    }
  }
}
