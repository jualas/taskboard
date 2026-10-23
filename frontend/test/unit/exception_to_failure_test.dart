import 'package:flutter_test/flutter_test.dart';
import 'package:personal_taskboard/core/error/exception_to_failure.dart';
import 'package:personal_taskboard/core/error/exceptions.dart';
import 'package:personal_taskboard/core/error/failures.dart';

void main() {
  test('mapea UnauthorizedException', () {
    final f = mapExceptionToFailure(const UnauthorizedException());
    expect(f, isA<UnauthorizedFailure>());
  });

  test('mapea NotFoundException', () {
    final f = mapExceptionToFailure(const NotFoundException());
    expect(f, isA<NotFoundFailure>());
  });

  test('mapea ServerException con código', () {
    final f = mapExceptionToFailure(
      const ServerException('fallo', statusCode: 500),
    );
    expect(f, isA<ServerFailure>());
    expect((f as ServerFailure).statusCode, 500);
  });

  test('mapea Exception genérica con 401 en texto', () {
    final f = mapExceptionToFailure(
      Exception('Sesión no válida (401)'),
    );
    expect(f, isA<UnauthorizedFailure>());
  });
}
