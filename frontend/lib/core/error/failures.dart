/// Errores de dominio / presentación (sin detalles de implementación HTTP).
sealed class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Error de red. Comprueba la conexión.']);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([
    super.message = 'Sesión no válida o caducada. Vuelve a iniciar sesión.',
  ]);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Recurso no encontrado.']);
}

class ServerFailure extends Failure {
  const ServerFailure({
    this.statusCode,
    String message = 'Error del servidor.',
  }) : super(message);

  final int? statusCode;
}

/// Datos de entrada no válidos (reglas de dominio).
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Ha ocurrido un error inesperado.']);
}
