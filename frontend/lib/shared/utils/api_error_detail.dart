import 'dart:convert';

/// Extrae el `detail` de un cuerpo de error FastAPI incrustado en un texto
/// (p. ej. `Error IA (502): {"detail": "…"}`). Null si no hay JSON o detalle.
String? fastApiDetailFromErrorString(String errorString) {
  final i = errorString.indexOf('{');
  if (i < 0) return null;
  try {
    final map = jsonDecode(errorString.substring(i)) as Map<String, dynamic>?;
    if (map == null) return null;
    final d = map['detail'];
    if (d is String && d.trim().isNotEmpty) return d.trim();
  } catch (_) {}
  return null;
}
