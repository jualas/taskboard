import 'package:flutter_test/flutter_test.dart';
import 'package:personal_taskboard/core/error/failures.dart';
import 'package:personal_taskboard/features/ai_assistant/presentation/utils/ai_error_messages.dart';
import 'package:personal_taskboard/shared/utils/api_error_detail.dart';

void main() {
  test('fastApiDetailFromErrorString extrae detail o devuelve null', () {
    expect(
      fastApiDetailFromErrorString('Error IA (502): {"detail": " sin saldo "}'),
      'sin saldo',
    );
    expect(fastApiDetailFromErrorString('Error IA (502): <html>'), isNull);
    expect(fastApiDetailFromErrorString('Error IA (502): {roto'), isNull);
  });

  group('describeAiFailure', () {
    String d(String message) =>
        describeAiFailure(ServerFailure(message: message));

    test('504 usa el detail del API si existe', () {
      expect(d('Error IA (504): {"detail": "Tardó 20 min"}'), 'Tardó 20 min');
      expect(
        d('Error IA (504): Gateway Timeout'),
        startsWith('El asistente IA tardó demasiado'),
      );
    });

    test('timeout del cliente', () {
      expect(
        describeAiFailure(
          const UnexpectedFailure('TimeoutException after 0:25:00'),
        ),
        startsWith('La consulta al asistente IA tardó demasiado'),
      );
    });

    test('fallo de red', () {
      expect(
        describeAiFailure(
          const UnexpectedFailure('ClientException: Failed to fetch'),
        ),
        startsWith('No se pudo llamar a la función IA'),
      );
    });

    test('402 de DeepSeek', () {
      expect(
        d('Error IA (402): Insufficient Balance'),
        startsWith('DeepSeek: la cuenta no tiene saldo'),
      );
    });

    test('502 sin detail', () {
      expect(d('Error IA (502): boom'), startsWith('Error 502'));
    });

    test('resto de errores conserva el texto', () {
      expect(
        d('Error IA (500): x'),
        'No se pudo generar sugerencia IA: Error IA (500): x',
      );
    });
  });
}
