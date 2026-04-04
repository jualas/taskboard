import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:personal_taskboard/services/api/taskboard_api_client.dart' show TaskboardApiClient;
import 'package:personal_taskboard/services/services.dart' show TaskboardApiClient;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

const _kTokenKey = 'taskboard_api_access_token';
const _kEmailKey = 'taskboard_api_user_email';
const _kUserIdKey = 'taskboard_api_user_id';

/// Autenticación JWT contra el backend FastAPI [TaskboardApiClient.baseUrl].
class ApiAuthService extends ChangeNotifier implements AuthService {
  ApiAuthService({
    required this.baseUrl,
    required SharedPreferences prefs,
  }) : _prefs = prefs;

  final String baseUrl;
  final SharedPreferences _prefs;

  String? _token;
  String? _email;
  String? _userId;

  @override
  bool get isAuthenticated =>
      _token != null && _token!.isNotEmpty && _userId != null;

  @override
  String? get currentUserEmail => _email;

  @override
  String? get currentUserId => _userId;

  @override
  String? get currentUserName => null;

  String? get accessToken => _token;

  String get _origin => baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;

  @override
  Future<void> init() async {
    _token = _prefs.getString(_kTokenKey);
    _email = _prefs.getString(_kEmailKey);
    _userId = _prefs.getString(_kUserIdKey);
    notifyListeners();
  }

  @override
  Future<bool> validateCredentials(String email, String password) =>
      login(email, password);

  @override
  Future<bool> login(String email, String password) async {
    final uri = Uri.parse('$_origin/auth/login');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode == 401) {
      throw Exception('Credenciales incorrectas');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Login API (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = data['access_token'] as String?;
    final user = data['user'] as Map<String, dynamic>?;
    if (token == null || user == null) {
      throw Exception('Respuesta de login inválida');
    }
    _token = token;
    _email = user['email'] as String?;
    _userId = user['id'] as String?;
    await _prefs.setString(_kTokenKey, token);
    if (_email != null) await _prefs.setString(_kEmailKey, _email!);
    if (_userId != null) await _prefs.setString(_kUserIdKey, _userId!);
    notifyListeners();
    return true;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final t = _token;
    if (t == null || t.isEmpty) {
      throw Exception('No hay sesión. Inicia sesión de nuevo.');
    }
    final uri = Uri.parse('$_origin/auth/change-password');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $t',
      },
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    if (res.statusCode == 401) {
      throw Exception('Contraseña actual incorrecta');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Cambio de contraseña (${res.statusCode}): ${res.body}');
    }
  }

  @override
  Future<void> logout() async {
    _token = null;
    _email = null;
    _userId = null;
    await _prefs.remove(_kTokenKey);
    await _prefs.remove(_kEmailKey);
    await _prefs.remove(_kUserIdKey);
    notifyListeners();
  }
}
