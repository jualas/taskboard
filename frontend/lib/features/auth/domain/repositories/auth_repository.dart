import '../../../../core/error/result.dart';
import '../entities/auth_user.dart';

abstract class AuthRepository {
  /// Sesión en memoria; null si no hay usuario autenticado.
  AuthUser? get currentUser;

  /// Emite cada vez que se inicia o se cierra sesión.
  Stream<AuthUser?> get sessionChanges;

  /// Recupera la sesión guardada (al arrancar o recargar la página).
  Future<Result<AuthUser?>> restoreSession();

  Future<Result<AuthUser>> login({
    required String email,
    required String password,
  });

  Future<Result<void>> logout();

  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
