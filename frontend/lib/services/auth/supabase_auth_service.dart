import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Autenticación vía Supabase Auth (modo legado).
class SupabaseAuthService implements AuthService {
  SupabaseAuthService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  bool get isAuthenticated => _client.auth.currentSession != null;

  @override
  String? get currentUserEmail => _client.auth.currentUser?.email;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  String? get currentUserName =>
      _client.auth.currentUser?.userMetadata?['name'] as String?;

  @override
  Future<void> init() async {}

  @override
  Future<bool> validateCredentials(String email, String password) =>
      login(email, password);

  @override
  Future<bool> login(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.session != null || response.user != null) {
      return true;
    }
    throw const AuthException(
      'Respuesta de autenticación inválida: sin sesión ni usuario',
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> logout() async {
    await _client.auth.signOut();
  }
}
