import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/token_provider.dart';
import '../models/auth_session_model.dart';

/// Persistencia de la sesión en SharedPreferences.
///
/// También es el [TokenProvider] de `TaskboardApiClient`.
abstract class AuthLocalDataSource implements TokenProvider {
  AuthSessionModel? readSession();

  Future<void> saveSession(AuthSessionModel session);

  Future<void> clearSession();
}

const _kTokenKey = 'taskboard_api_access_token';
const _kEmailKey = 'taskboard_api_user_email';
const _kUserIdKey = 'taskboard_api_user_id';

/// Token JWT y usuario del API (mismas claves que la versión anterior,
/// para no cerrar las sesiones abiertas al desplegar).
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? get accessToken => _prefs.getString(_kTokenKey);

  @override
  AuthSessionModel? readSession() {
    final token = accessToken;
    final userId = _prefs.getString(_kUserIdKey);
    if (token == null || token.isEmpty || userId == null) return null;
    return AuthSessionModel(
      userId: userId,
      accessToken: token,
      email: _prefs.getString(_kEmailKey),
    );
  }

  @override
  Future<void> saveSession(AuthSessionModel session) async {
    final token = session.accessToken;
    if (token != null) await _prefs.setString(_kTokenKey, token);
    final email = session.email;
    if (email != null) await _prefs.setString(_kEmailKey, email);
    await _prefs.setString(_kUserIdKey, session.userId);
  }

  @override
  Future<void> clearSession() async {
    await _prefs.remove(_kTokenKey);
    await _prefs.remove(_kEmailKey);
    await _prefs.remove(_kUserIdKey);
  }
}

const _kLocalAuth = 'taskboard_local_demo_auth';
const _kLocalEmail = 'taskboard_local_demo_email';
const _kLocalUserId = 'local-user';
const _kLocalUserName = 'Usuario local';

/// Sesión local de demostración cuando no hay API configurada (datos en JSON).
class DemoAuthLocalDataSource implements AuthLocalDataSource {
  DemoAuthLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  /// Sin API no hay token.
  @override
  String? get accessToken => null;

  @override
  AuthSessionModel? readSession() {
    if (!(_prefs.getBool(_kLocalAuth) ?? false)) return null;
    return AuthSessionModel(
      userId: _kLocalUserId,
      email: _prefs.getString(_kLocalEmail),
      name: _kLocalUserName,
    );
  }

  @override
  Future<void> saveSession(AuthSessionModel session) async {
    await _prefs.setBool(_kLocalAuth, true);
    final email = session.email;
    if (email != null) await _prefs.setString(_kLocalEmail, email);
  }

  @override
  Future<void> clearSession() async {
    await _prefs.remove(_kLocalAuth);
    await _prefs.remove(_kLocalEmail);
  }
}
