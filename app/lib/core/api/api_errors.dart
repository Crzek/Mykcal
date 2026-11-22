/// Errores tipados del API. La UI muestra su propio texto según el tipo y el `code`.
sealed class ApiFailure implements Exception {
  const ApiFailure();
}

/// El servidor respondió con un `ErrorBody` (p. ej. `INVITATION_INVALID`, `NO_SEATS`).
class ApiError extends ApiFailure {
  const ApiError(this.code, this.status, {this.retryAfterSeconds});

  final String code;
  final int status;
  final int? retryAfterSeconds;

  @override
  String toString() => 'ApiError($code, $status)';
}

/// Sin red o plazo agotado (FR-015).
class NetworkFailure extends ApiFailure {
  const NetworkFailure();
}

/// El servidor falló o no responde (5xx, `AUTH_UNAVAILABLE`).
class ServerFailure extends ApiFailure {
  const ServerFailure();
}

/// La sesión no se pudo renovar: hay que iniciar sesión de nuevo.
class SessionExpired extends ApiFailure {
  const SessionExpired();
}
