import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_errors.dart';
import '../api/models.dart';
import '../api/mykcal_api.dart';
import 'auth_service.dart';
import 'session_store.dart';

/// Margen para renovar el access token antes de que caduque.
const renewMargin = Duration(seconds: 60);

/// Avisos de la pantalla de acceso.
enum AccessNotice {
  signInFailed,
  unavailable,
  sessionExpired,
  accountDeactivated,
}

/// Estado de la cuenta (data-model.md, «Estado en la app»).
sealed class AccountState {
  const AccountState();
}

class SignedOut extends AccountState {
  const SignedOut({this.notice, this.busy = false});

  final AccessNotice? notice;

  /// El navegador está abierto o se están revocando los tokens.
  final bool busy;
}

/// Sesión válida pero sin cuenta de Mykcal: toca introducir el código.
class NeedsRegistration extends AccountState {
  const NeedsRegistration();
}

class Active extends AccountState {
  const Active(this.me);

  final Me me;
}

class Disabled extends AccountState {
  const Disabled(this.me);

  final Me me;
}

/// No se pudo consultar la cuenta (sin red o servidor caído); se puede reintentar.
class ConnectionError extends AccountState {
  const ConnectionError({required this.offline});

  final bool offline;
}

/// Plazo total para revocar los tokens al cerrar sesión; pasado, se cierra igual.
final signOutDeadlineProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);

/// Reloj inyectable para las pruebas.
final authClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class AuthController extends AsyncNotifier<AccountState> {
  Future<String?>? _refreshing;

  SessionStore get _store => ref.read(sessionStoreProvider);
  AuthService get _auth => ref.read(authServiceProvider);
  MykcalApi get _api => ref.read(mykcalApiProvider);
  DateTime _now() => ref.read(authClockProvider)().toUtc();

  @override
  Future<AccountState> build() async {
    final session = await _store.read();
    if (session == null) return const SignedOut();
    return _loadAccount();
  }

  Future<AccountState> _loadAccount() async {
    try {
      final me = await _api.me();
      return me.active ? Active(me) : Disabled(me);
    } on ApiError catch (e) {
      if (e.code == 'ACCOUNT_NOT_REGISTERED') return const NeedsRegistration();
      return const ConnectionError(offline: false);
    } on SessionExpired {
      await _store.clear();
      return const SignedOut(notice: AccessNotice.sessionExpired);
    } on NetworkFailure {
      return const ConnectionError(offline: true);
    } on ApiFailure {
      return const ConnectionError(offline: false);
    }
  }

  /// Vuelve a pedir `/v1/me` sin pasar por la pantalla de carga (p. ej. tras aceptar el
  /// consentimiento o terminar el onboarding).
  Future<void> refreshAccount() async {
    state = AsyncData(await _loadAccount());
  }

  /// Da de baja la cuenta y cierra la sesión. Los errores del API llegan a quien llama.
  Future<void> deactivate() async {
    await _api.deactivate();
    await signOut();
    state = const AsyncData(SignedOut(notice: AccessNotice.accountDeactivated));
  }

  /// Vuelve a consultar la cuenta tras un error de conexión.
  Future<void> retry() async {
    state = const AsyncLoading<AccountState>().copyWithPrevious(state);
    state = AsyncData(await _loadAccount());
  }

  Future<void> signIn({bool register = false}) async {
    state = const AsyncData(SignedOut(busy: true));
    try {
      final tokens = await _auth.signIn(register: register);
      final refresh = tokens.refreshToken;
      if (refresh == null || refresh.isEmpty) {
        // Sin refresh token no se podría renovar: no se guarda una sesión que caduca a los 15 min.
        unawaited(_revokeQuietly(tokens.accessToken));
        throw const SignInFailed();
      }
      await _store.write(
        StoredSession(
          accessToken: tokens.accessToken,
          refreshToken: refresh,
          accessTokenExpiresAt: _effectiveExpiry(tokens),
          idToken: tokens.idToken,
        ),
      );
      state = AsyncData(await _loadAccount());
    } on SignInCancelled {
      state = const AsyncData(SignedOut());
    } on AuthServiceUnavailable {
      state = const AsyncData(SignedOut(notice: AccessNotice.unavailable));
    } on Object {
      state = const AsyncData(SignedOut(notice: AccessNotice.signInFailed));
    }
  }

  /// Crea la cuenta de Mykcal con el código. Los errores del API llegan a quien llama.
  Future<void> register(String invitationCode) async {
    final me = await _api.register(invitationCode);
    state = AsyncData(me.active ? Active(me) : Disabled(me));
  }

  /// Token para la siguiente petición; lo renueva si le queda poco. `null` si no hay sesión.
  Future<String?> validAccessToken() async {
    final session = await _store.read();
    if (session == null) return null;
    if (session.accessTokenExpiresAt.difference(_now()) > renewMargin) {
      return session.accessToken;
    }
    return _refresh(session);
  }

  /// El API rechazó un token que parecía válido: se renueva una vez.
  Future<String?> forceRefresh() async {
    final session = await _store.read();
    if (session == null) return null;
    return _refresh(session);
  }

  /// Las renovaciones simultáneas comparten una sola llamada a Zitadel.
  Future<String?> _refresh(StoredSession session) {
    return _refreshing ??= _doRefresh(session)
        .whenComplete(() => _refreshing = null);
  }

  Future<String?> _doRefresh(StoredSession session) async {
    try {
      final tokens = await _auth.refresh(session.refreshToken);
      // Zitadel rota el refresh token: se guarda siempre el último.
      await _store.write(
        StoredSession(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken ?? session.refreshToken,
          accessTokenExpiresAt: _effectiveExpiry(tokens),
          idToken: tokens.idToken ?? session.idToken,
        ),
      );
      return tokens.accessToken;
    } on RefreshRejected {
      return null;
    } on Object {
      // Fallo temporal: la sesión guardada no se toca y la petición falla como de red.
      throw const NetworkFailure();
    }
  }

  /// Sesión caducada o revocada durante el uso: vuelve al acceso. Los borradores de pantalla
  /// viven en sus propios providers y se conservan.
  Future<void> markExpired() async {
    await _store.clear();
    state = const AsyncData(SignedOut(notice: AccessNotice.sessionExpired));
  }

  /// Revoca, borra y cierra la sesión del navegador. Los tokens se borran pase lo que pase.
  Future<void> signOut() async {
    final session = await _store.read();
    state = const AsyncData(SignedOut(busy: true));
    if (session != null) {
      try {
        await Future.wait([
          _revokeQuietly(session.refreshToken),
          _revokeQuietly(session.accessToken),
        ]).timeout(ref.read(signOutDeadlineProvider));
      } on TimeoutException {
        // La sesión local se borra igual.
      }
    }
    await _store.clear();
    state = const AsyncData(SignedOut());
    try {
      await _auth.endSession(session?.idToken);
    } on Object {
      // Sin red o navegador cerrado: la sesión local ya no existe.
    }
  }

  Future<void> _revokeQuietly(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await _auth.revoke(token);
    } on Object {
      // Sin red: la sesión local se borra igual.
    }
  }

  /// mín(`exp` del servidor, ahora + 15 min): el access token vive 15 min.
  DateTime _effectiveExpiry(TokenSet tokens) {
    final now = _now();
    final cap = now.add(const Duration(minutes: 15));
    final expiry =
        tokens.expiresAt?.toUtc() ?? _jwtExp(tokens.accessToken) ?? cap;
    return expiry.isBefore(cap) ? expiry : cap;
  }
}

DateTime? _jwtExp(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final exp = decoded is Map<String, dynamic> ? decoded['exp'] : null;
    return exp is int
        ? DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true)
        : null;
  } on FormatException {
    return null;
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AccountState>(AuthController.new);
