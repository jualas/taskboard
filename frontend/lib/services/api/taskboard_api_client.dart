import 'dart:async';
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
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$origin$path');
    final h = _headers(jsonBody: true);
    if (extraHeaders != null) {
      h.addAll(extraHeaders);
    }
    final future = http.post(
      uri,
      headers: h,
      body: body == null ? null : jsonEncode(body),
    );
    if (timeout != null) {
      return future.timeout(timeout);
    }
    return future;
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

  /// POST con respuesta SSE (`text/event-stream`), líneas `data: {...}`.
  Stream<Map<String, dynamic>> postSseStream(
    String path, {
    required Object body,
  }) async* {
    final uri = Uri.parse('$origin$path');
    final request = http.Request('POST', uri);
    request.headers.addAll(_headers(jsonBody: true));
    request.headers['Accept'] = 'text/event-stream';
    request.body = jsonEncode(body);

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode >= 400) {
        final errBody = await response.stream.bytesToString();
        throw Exception('Error IA (${response.statusCode}): $errBody');
      }

      var buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        while (true) {
          final sep = buffer.indexOf('\n\n');
          if (sep < 0) break;
          final block = buffer.substring(0, sep);
          buffer = buffer.substring(sep + 2);
          for (final line in block.split('\n')) {
            if (!line.startsWith('data:')) continue;
            final raw = line.substring(5).trim();
            if (raw.isEmpty) continue;
            try {
              final decoded = jsonDecode(raw);
              if (decoded is Map) {
                yield Map<String, dynamic>.from(decoded);
              }
            } catch (_) {}
          }
        }
      }
    } finally {
      client.close();
    }
  }
}
