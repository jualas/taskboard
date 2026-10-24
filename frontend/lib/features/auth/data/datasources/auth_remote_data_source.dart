import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/error/exceptions.dart';
import '../models/auth_session_model.dart';

/// Autenticación JWT contra el backend FastAPI.
abstract class AuthRemoteDataSource {
  Future<AuthSessionModel> login(String email, String password);

  Future<void> changePassword({
    required String accessToken,
    required String currentPassword,
    required String newPassword,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({required String baseUrl, http.Client? client})
    : _origin = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      _client = client ?? http.Client();

  final String _origin;
  final http.Client _client;

  @override
  Future<AuthSessionModel> login(String email, String password) async {
    final res = await _post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    if (res.statusCode == 401) {
      throw const UnauthorizedException('Credenciales incorrectas');
    }
    _throwIfNotOk(res, 'Login API');
    final session = AuthSessionModel.fromLoginJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
    if (session == null) {
      throw const ServerException('Respuesta de login inválida');
    }
    return session;
  }

  @override
  Future<void> changePassword({
    required String accessToken,
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await _post(
      '/auth/change-password',
      accessToken: accessToken,
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
    if (res.statusCode == 401) {
      throw const UnauthorizedException('Contraseña actual incorrecta');
    }
    _throwIfNotOk(res, 'Cambio de contraseña');
  }

  Future<http.Response> _post(
    String path, {
    required Object body,
    String? accessToken,
  }) async {
    try {
      return await _client.post(
        Uri.parse('$_origin$path'),
        headers: {
          'Content-Type': 'application/json',
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body),
      );
    } on http.ClientException catch (e) {
      throw NetworkException('Error de red: ${e.message}');
    }
  }

  void _throwIfNotOk(http.Response res, String context) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ServerException(
        '$context (${res.statusCode}): ${res.body}',
        statusCode: res.statusCode,
      );
    }
  }
}
