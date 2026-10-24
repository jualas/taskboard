import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/usecases/auth_usecases.dart';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class AuthLogoutRequested extends AuthEvent {}

// States
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final String email;

  const AuthAuthenticated({required this.email});

  @override
  List<Object> get props => [email];
}

class AuthUnauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object> get props => [message];
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required RestoreSession restoreSession,
    required Login login,
    required Logout logout,
    required this.changePassword,
  }) : _restoreSession = restoreSession,
       _login = login,
       _logout = logout,
       super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
  }

  final RestoreSession _restoreSession;
  final Login _login;
  final Logout _logout;

  /// Lo usa el diálogo de cambio de contraseña, que espera el resultado.
  final ChangePassword changePassword;

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _restoreSession(const NoParams());
    final user = result.valueOrNull;
    if (user != null) {
      emit(AuthAuthenticated(email: user.email));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _login(
      LoginParams(email: event.email, password: event.password),
    );
    result.when(
      success: (user) => emit(AuthAuthenticated(email: user.email)),
      onFailure: (f) =>
          emit(AuthFailure('Error al iniciar sesión: ${f.message}')),
    );
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _logout(const NoParams());
    result.when(
      success: (_) => emit(AuthUnauthenticated()),
      onFailure: (f) =>
          emit(AuthFailure('Error al cerrar sesión: ${f.message}')),
    );
  }
}
