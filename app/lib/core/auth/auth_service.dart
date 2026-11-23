import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tokens que devuelve Zitadel al iniciar sesión o renovar.
class TokenSet {
  const TokenSet({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    this.expiresAt,
  });

  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime? expiresAt;
}

/// El usuario cerró el navegador o canceló: no es un error.
class SignInCancelled implements Exception {
  const SignInCancelled();
}

/// Zitadel no responde, no hay red o la app no está configurada con `https://`.
class AuthServiceUnavailable implements Exception {
  const AuthServiceUnavailable();
}

/// Zitadel terminó el inicio de sesión con un error.
class SignInFailed implements Exception {
  const SignInFailed();
}

/// Zitadel rechazó el refresh token: sesión caducada o revocada.
class RefreshRejected implements Exception {
  const RefreshRejected();
}

/// La renovación falló sin invalidar la sesión (sin red, plazo…).
class RefreshFailed implements Exception {
  const RefreshFailed();
}

/// Habla con Zitadel por OIDC. Las pruebas sustituyen esta interfaz.
abstract class AuthService {
  /// Abre la página de acceso (Authorization Code + PKCE). Con [register], la de registro.
  Future<TokenSet> signIn({bool register = false});

  Future<TokenSet> refresh(String refreshToken);

  /// Revoca un token en el servidor (RFC 7009).
  Future<void> revoke(String token);

  /// Cierra la sesión del navegador.
  Future<void> endSession(String? idTokenHint);
}

class AppAuthService implements AuthService {
  AppAuthService({
    FlutterAppAuth? appAuth,
    Dio? dio,
    this.issuer = const String.fromEnvironment('OIDC_ISSUER'),
    this.clientId = const String.fromEnvironment('OIDC_CLIENT_ID'),
    this.projectId = const String.fromEnvironment('OIDC_PROJECT_ID'),
    this.orgId = const String.fromEnvironment('OIDC_ORG_ID'),
    this.redirectUrl = const String.fromEnvironment('OIDC_REDIRECT_URL'),
    this.postLogoutRedirectUrl = const String.fromEnvironment('OIDC_LOGOUT_URL'),
  })  : _appAuth = appAuth ?? const FlutterAppAuth(),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: requestTimeout,
              sendTimeout: requestTimeout,
              receiveTimeout: requestTimeout,
            ));

  /// Plazo de cada llamada a Zitadel: nunca esperan sin límite.
  static const requestTimeout = Duration(seconds: 10);

  @visibleForTesting
  BaseOptions get dioOptions => _dio.options;

  final String issuer;
  final String clientId;
  final String projectId;
  final String orgId;
  final String redirectUrl;
  final String postLogoutRedirectUrl;
  final FlutterAppAuth _appAuth;
  final Dio _dio;
  String? _revocationEndpoint;

  List<String> get _scopes => [
        'openid',
        'profile',
        'email',
        'offline_access',
        if (orgId.isNotEmpty) 'urn:zitadel:iam:org:id:$orgId',
        'urn:zitadel:iam:org:project:id:$projectId:aud',
      ];

  /// Sin TLS hacia Zitadel no se abre el navegador.
  bool get configured =>
      issuer.startsWith('https://') &&
      clientId.isNotEmpty &&
      projectId.isNotEmpty &&
      redirectUrl.isNotEmpty;

  @override
  Future<TokenSet> signIn({bool register = false}) async {
    if (!configured) throw const AuthServiceUnavailable();
    try {
      final response = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          clientId,
          redirectUrl,
          issuer: issuer,
          scopes: _scopes,
          promptValues: register ? const ['create'] : null,
          additionalParameters: const {'ui_locales': 'es'},
        ),
      );
      final access = response.accessToken;
      if (access == null) throw const SignInFailed();
      return TokenSet(
        accessToken: access,
        refreshToken: response.refreshToken,
        idToken: response.idToken,
        expiresAt: response.accessTokenExpirationDateTime,
      );
    } on FlutterAppAuthUserCancelledException {
      throw const SignInCancelled();
    } on FlutterAppAuthPlatformException catch (e) {
      if (e.platformErrorDetails.error != null) throw const SignInFailed();
      throw const AuthServiceUnavailable();
    } on PlatformException {
      throw const AuthServiceUnavailable();
    }
  }

  @override
  Future<TokenSet> refresh(String refreshToken) async {
    // Solo `invalid_grant` invalida la sesión (RFC 6749 §5.2); el resto es temporal.
    if (!configured) throw const RefreshFailed();
    try {
      final response = await _appAuth.token(
        TokenRequest(
          clientId,
          redirectUrl,
          issuer: issuer,
          scopes: _scopes,
          refreshToken: refreshToken,
          grantType: GrantType.refreshToken,
        ),
      );
      final access = response.accessToken;
      if (access == null) throw const RefreshFailed();
      return TokenSet(
        accessToken: access,
        refreshToken: response.refreshToken,
        idToken: response.idToken,
        expiresAt: response.accessTokenExpirationDateTime,
      );
    } on FlutterAppAuthPlatformException catch (e) {
      if (e.platformErrorDetails.error == 'invalid_grant') throw const RefreshRejected();
      throw const RefreshFailed();
    } on PlatformException {
      throw const RefreshFailed();
    }
  }

  @override
  Future<void> revoke(String token) async {
    if (!configured) return;
    final endpoint = _revocationEndpoint ??= await _discover('revocation_endpoint');
    await _dio.post<void>(
      endpoint,
      data: {'token': token, 'client_id': clientId},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
  }

  @override
  Future<void> endSession(String? idTokenHint) async {
    if (!configured || idTokenHint == null) return;
    await _appAuth.endSession(
      EndSessionRequest(
        idTokenHint: idTokenHint,
        postLogoutRedirectUrl: postLogoutRedirectUrl,
        issuer: issuer,
      ),
    );
  }

  Future<String> _discover(String field) async {
    final response =
        await _dio.get<Map<String, dynamic>>('$issuer/.well-known/openid-configuration');
    final value = response.data?[field];
    if (value is! String || !value.startsWith('https://')) {
      throw const AuthServiceUnavailable();
    }
    return value;
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AppAuthService());
