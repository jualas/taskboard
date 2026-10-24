import '../../domain/entities/auth_user.dart';

/// Sesión tal como llega del API o se guarda en SharedPreferences.
class AuthSessionModel {
  const AuthSessionModel({
    required this.userId,
    this.accessToken,
    this.email,
    this.name,
  });

  /// Respuesta de `POST /auth/login`: `{access_token, user: {id, email}}`.
  /// Devuelve null si falta el token o el usuario.
  static AuthSessionModel? fromLoginJson(Map<String, dynamic> json) {
    final token = json['access_token'] as String?;
    final user = json['user'] as Map<String, dynamic>?;
    final userId = user?['id'] as String?;
    if (token == null || userId == null) return null;
    return AuthSessionModel(
      userId: userId,
      accessToken: token,
      email: user?['email'] as String?,
    );
  }

  final String userId;
  final String? accessToken;
  final String? email;
  final String? name;

  AuthUser toEntity() => AuthUser(id: userId, email: email ?? '', name: name);
}
