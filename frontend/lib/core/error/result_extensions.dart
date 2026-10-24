import 'result.dart';

extension ResultRequire<T> on Result<T> {
  /// Lanza [Exception] con mensaje si el resultado es fallo.
  T require([String context = 'Operación']) {
    final failure = failureOrNull;
    if (failure != null) {
      throw Exception('$context: ${failure.message}');
    }
    return valueOrNull as T;
  }
}
