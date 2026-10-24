import '../error/result.dart';

abstract class UseCase<T, P> {
  Future<Result<T>> call(P params);
}

class NoParams {
  const NoParams();
}
