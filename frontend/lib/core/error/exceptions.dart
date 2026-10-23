/// Excepciones lanzadas en la capa data (traducidas a Failure en repositorios).
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'Error de red']);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'No autorizado']);
}

class NotFoundException extends AppException {
  const NotFoundException([super.message = 'No encontrado']);
}

class ServerException extends AppException {
  const ServerException(super.message, {this.statusCode});

  final int? statusCode;
}

class UnexpectedAppException extends AppException {
  const UnexpectedAppException([super.message = 'Error inesperado']);
}
