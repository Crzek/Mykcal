import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sesión de Zitadel guardada en el dispositivo (data-model.md, «Estado en la app»).
class StoredSession {
  const StoredSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    this.idToken,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final String? idToken;
}

/// Almacén seguro del sistema; los tokens no van nunca a `shared_preferences`.
class SessionStore {
  SessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const accessTokenKey = 'oidc.access_token';
  static const refreshTokenKey = 'oidc.refresh_token';
  static const idTokenKey = 'oidc.id_token';
  static const expiresAtKey = 'oidc.access_token_expires_at';
  static const allKeys = [
    accessTokenKey,
    refreshTokenKey,
    idTokenKey,
    expiresAtKey,
  ];

  /// Si el almacén no se puede descifrar (`BAD_DECRYPT`: la clave del sistema ya no encaja con
  /// los datos, p. ej. tras reinstalar o restaurar una copia), la sesión se da por perdida: se
  /// vacía y el usuario vuelve a iniciar sesión, en lugar de quedar bloqueado en el arranque.
  Future<StoredSession?> read() async {
    final Map<String, String> values;
    try {
      values = await _storage.readAll();
    } on PlatformException {
      try {
        await _storage.deleteAll();
      } on PlatformException {
        // Sin poder vaciarlo, igualmente se trata como sin sesión.
      }
      return null;
    }
    final access = values[accessTokenKey];
    final refresh = values[refreshTokenKey];
    final expires = DateTime.tryParse(values[expiresAtKey] ?? '');
    if (access == null || refresh == null || expires == null) return null;
    return StoredSession(
      accessToken: access,
      refreshToken: refresh,
      accessTokenExpiresAt: expires.toUtc(),
      idToken: values[idTokenKey],
    );
  }

  Future<void> write(StoredSession session) async {
    await _storage.write(key: accessTokenKey, value: session.accessToken);
    await _storage.write(key: refreshTokenKey, value: session.refreshToken);
    await _storage.write(
      key: expiresAtKey,
      value: session.accessTokenExpiresAt.toUtc().toIso8601String(),
    );
    if (session.idToken != null) {
      await _storage.write(key: idTokenKey, value: session.idToken);
    }
  }

  Future<void> clear() async {
    for (final key in allKeys) {
      await _storage.delete(key: key);
    }
  }
}

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());
