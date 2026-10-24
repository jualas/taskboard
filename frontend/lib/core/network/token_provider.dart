/// Origen del token de acceso para `TaskboardApiClient`.
///
/// Lo implementa la capa data de auth; core no depende de features.
abstract class TokenProvider {
  String? get accessToken;
}
