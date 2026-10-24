import 'package:equatable/equatable.dart';

/// Usuario con sesión iniciada (API JWT o modo local de demostración).
class AuthUser extends Equatable {
  const AuthUser({required this.id, required this.email, this.name});

  final String id;
  final String email;

  /// Nombre mostrado si existe (metadatos o perfil).
  final String? name;

  @override
  List<Object?> get props => [id, email, name];
}
