/// Contrato de autenticación (Supabase, API REST o modo local).
abstract class AuthService {
  bool get isAuthenticated;

  String? get currentUserEmail;

  String? get currentUserId;

  /// Nombre mostrado si existe (metadatos o perfil).
  String? get currentUserName;

  Future<void> init();

  Future<bool> login(String email, String password);

  Future<void> logout();

  /// Cambia la contraseña del usuario autenticado (si el backend lo soporta).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<bool> validateCredentials(String email, String password) =>
      login(email, password);
}
