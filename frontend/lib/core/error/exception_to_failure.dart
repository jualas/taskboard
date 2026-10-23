import 'exceptions.dart';
import 'failures.dart';

Failure mapExceptionToFailure(Object error) {
  if (error is UnauthorizedException) {
    return UnauthorizedFailure(error.message);
  }
  if (error is NotFoundException) {
    return NotFoundFailure(error.message);
  }
  if (error is NetworkException) {
    return NetworkFailure(error.message);
  }
  if (error is ServerException) {
    return ServerFailure(
      statusCode: error.statusCode,
      message: error.message,
    );
  }
  if (error is UnexpectedAppException) {
    return UnexpectedFailure(error.message);
  }
  if (error is AppException) {
    return UnexpectedFailure(error.message);
  }

  final text = error.toString();
  if (text.contains('401') || text.contains('Sesión no válida')) {
    return const UnauthorizedFailure();
  }
  if (text.contains('403') || text.contains('Permiso denegado')) {
    return const ServerFailure(message: 'Permiso denegado.');
  }
  if (text.contains('404') || text.contains('no encontrad')) {
    return const NotFoundFailure();
  }
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused')) {
    return const NetworkFailure();
  }

  return UnexpectedFailure(text);
}

/// Convierte errores genéricos de [TaskboardDataSource] / HTTP legacy.
Never rethrowAsAppException(Object error, {String? context}) {
  if (error is AppException) throw error;
  final text = error.toString();
  if (text.contains('401')) {
    throw const UnauthorizedException(
      'Sesión no válida o caducada. Cierra sesión y vuelve a entrar.',
    );
  }
  if (text.contains('403')) {
    throw ServerException(
      context != null ? 'Permiso denegado (403). $context' : text,
      statusCode: 403,
    );
  }
  if (text.contains('404') || text.toLowerCase().contains('no encontrad')) {
    throw NotFoundException(text);
  }
  throw UnexpectedAppException(context != null ? '$context: $text' : text);
}
