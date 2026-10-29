import '../../../../core/error/failures.dart';
import '../../../../shared/utils/api_error_detail.dart';

/// Mensaje para el usuario a partir del fallo de una consulta IA.
String describeAiFailure(Failure failure) {
  final s = failure.message;
  if (s.contains('504') || s.contains('Gateway Timeout')) {
    final detail = fastApiDetailFromErrorString(s);
    if (detail != null) return detail;
    return 'El asistente IA tardó demasiado. Divide la petición o inténtalo de nuevo.';
  }
  if (s.contains('TimeoutException') || s.contains('timed out')) {
    return 'La consulta al asistente IA tardó demasiado. '
        'Prueba un mensaje más corto o divide la petición (p. ej. primero alinear tareas, luego repo). '
        'Las peticiones complejas pueden tardar varios minutos.';
  }
  if (s.contains('Failed to fetch') ||
      s.contains('Failed to execute fetch') ||
      s.contains('ClientException') ||
      s.contains('XMLHttpRequest error') ||
      s.contains('NetworkError')) {
    return 'No se pudo llamar a la función IA: fallo de red o respuesta inválida. '
        'Comprueba la URL del API, proxy mismo-origen y CORS.';
  }
  if (s.contains('CORS') || s.contains('Access-Control-Allow-Origin')) {
    return 'CORS: el API no autoriza este origen. Revisa el proxy o cabeceras del servidor.';
  }
  if (s.contains('402') ||
      s.contains('Insufficient Balance') ||
      s.contains('saldo insuficiente')) {
    return 'DeepSeek: la cuenta no tiene saldo o créditos. Recarga en https://platform.deepseek.com/';
  }
  if (s.contains('502')) {
    final detail = fastApiDetailFromErrorString(s);
    if (detail != null) return detail;
    return 'Error 502: fallo al hablar con el proveedor IA. Revisa logs del contenedor taskboard-api.';
  }
  if (s.contains('no disponible en modo local')) {
    return 'La IA no está disponible sin API Taskboard. Configura TASKBOARD_API_URL o taskboardApi en config.json.';
  }
  return 'No se pudo generar sugerencia IA: $s';
}
