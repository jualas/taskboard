import 'dart:convert';

import 'package:http/http.dart' as http;

import '../error/exception_to_failure.dart';
import '../error/exceptions.dart';

/// Ayudas comunes de los data sources que hablan con el API TaskBoard.

/// Lanza la [AppException] que corresponde a una respuesta fuera de 2xx.
/// `action` describe la operación para el mensaje («Listar proyectos»).
void ensureSuccess(http.Response res, String action) {
  final code = res.statusCode;
  if (code >= 200 && code < 300) return;
  if (code == 401) {
    throw const UnauthorizedException(
      'Sesión no válida o caducada. Cierra sesión y vuelve a entrar.',
    );
  }
  if (code == 403) {
    throw ServerException('Permiso denegado (403). $action', statusCode: 403);
  }
  if (code == 404) {
    throw NotFoundException('$action (404): ${res.body}');
  }
  throw ServerException('$action ($code): ${res.body}', statusCode: code);
}

/// Ejecuta una llamada al API y convierte cualquier error que no sea ya una
/// [AppException] (red, token ausente, JSON roto…) con el contexto `action`.
Future<T> guardApiCall<T>(String action, Future<T> Function() call) async {
  try {
    return await call();
  } catch (e) {
    rethrowAsAppException(e, context: action);
  }
}

List<Map<String, dynamic>> decodeJsonList(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) {
    throw const ServerException('Respuesta no es lista JSON');
  }
  return decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
}

Map<String, dynamic> decodeJsonMap(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const ServerException('Respuesta no es objeto JSON');
  }
  return Map<String, dynamic>.from(decoded);
}

/// Lee un entero de una respuesta de texto plano (`/api/meta/next-*-id`).
int parsePlainInt(String body, String action) {
  final n = int.tryParse(body.trim());
  if (n == null) {
    throw ServerException('Respuesta $action inválida: ${body.trim()}');
  }
  return n;
}
