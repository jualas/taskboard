import 'failures.dart';

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is ResultFailure<T>;

  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) onFailure,
  }) {
    return switch (this) {
      Success<T>(:final value) => success(value),
      ResultFailure<T>(:final failure) => onFailure(failure),
    };
  }

  R fold<R>(
    R Function(Failure failure) onFailure,
    R Function(T value) onSuccess,
  ) {
    return when(success: onSuccess, onFailure: onFailure);
  }

  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        ResultFailure<T>() => null,
      };

  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        ResultFailure<T>(:final failure) => failure,
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.failure);

  final Failure failure;
}
