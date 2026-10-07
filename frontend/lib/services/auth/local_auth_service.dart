import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

const _kLocalAuth = 'taskboard_local_demo_auth';
const _kLocalEmail = 'taskboard_local_demo_email';

/// Sesión local de demostración cuando no hay API configurada (datos en JSON).
class LocalAuthService implements AuthService {
  LocalAuthService(this._prefs);

  final SharedPreferences _prefs;

  @override
  bool get isAuthenticated => _prefs.getBool(_kLocalAuth) ?? false;

  @override
  String? get currentUserEmail => _prefs.getString(_kLocalEmail);

  @override
  String? get currentUserId => 'local-user';

  @override
  String? get currentUserName => 'Usuario local';

  @override
  Future<void> init() async {}

  @override
  Future<bool> validateCredentials(String email, String password) =>
      login(email, password);

  @override
  Future<bool> login(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw Exception('Introduce email y contraseña');
    }
    await _prefs.setBool(_kLocalAuth, true);
    await _prefs.setString(_kLocalEmail, email.trim());
    return true;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    throw UnsupportedError('El modo local no soporta cambio de contraseña');
  }

  @override
  Future<void> logout() async {
    await _prefs.remove(_kLocalAuth);
    await _prefs.remove(_kLocalEmail);
  }
}
