import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente HTTP hacia el backend TaskBoard (FastAPI), con Bearer JWT.
class TaskboardApiClient {
  TaskboardApiClient({
    required this.baseUrl,
    required this.accessTokenProvider,
  });

  final String baseUrl;
  final String? Function() accessTokenProvider;

  String get origin =>
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  Map<String, String> _headers({bool jsonBody = false}) {
    final t = accessTokenProvider();
    if (t == null || t.isEmpty) {
      throw Exception('No hay token de acceso. Inicia sesión de nuevo.');
    }
    final h = <String, String>{'Authorization': 'Bearer $t'};
    if (jsonBody) h['Content-Type'] = 'application/json';
    return h;
  }

  Future<http.Response> get(String path) async {
    final uri = Uri.parse('$origin$path');
    return http.get(uri, headers: _headers());
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$origin$path');
    final h = _headers(jsonBody: true);
    if (extraHeaders != null) {
      h.addAll(extraHeaders);
    }
    return http.post(
      uri,
      headers: h,
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> put(String path, {required Object body}) async {
    final uri = Uri.parse('$origin$path');
    return http.put(
      uri,
      headers: _headers(jsonBody: true),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> patch(String path, {required Object body}) async {
    final uri = Uri.parse('$origin$path');
    return http.patch(
      uri,
      headers: _headers(jsonBody: true),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> delete(String path) async {
    final uri = Uri.parse('$origin$path');
    return http.delete(uri, headers: _headers());
  }
}
