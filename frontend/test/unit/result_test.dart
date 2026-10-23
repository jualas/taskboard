import 'package:flutter_test/flutter_test.dart';
import 'package:personal_taskboard/core/error/failures.dart';
import 'package:personal_taskboard/core/error/result.dart';

void main() {
  test('Success expone valueOrNull', () {
    const r = Success<int>(42);
    expect(r.valueOrNull, 42);
    expect(r.failureOrNull, isNull);
  });

  test('ResultFailure expone failureOrNull', () {
    const f = NetworkFailure('offline');
    const r = ResultFailure<int>(f);
    expect(r.valueOrNull, isNull);
    expect(r.failureOrNull, f);
  });

  test('when distingue success y failure', () {
    const ok = Success<String>('hola');
    const bad = ResultFailure<String>(UnexpectedFailure());

    expect(
      ok.when(success: (v) => v, onFailure: (_) => 'err'),
      'hola',
    );
    expect(
      bad.when(success: (_) => 'ok', onFailure: (f) => f.message),
      isNotEmpty,
    );
  });
}
