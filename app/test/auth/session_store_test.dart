import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mykcal/core/auth/session_store.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('guarda y lee la sesión', () async {
    final store = SessionStore();
    expect(await store.read(), isNull);
    final exp = DateTime.utc(2026, 11, 22, 12, 15);
    await store.write(
      StoredSession(
        accessToken: 'a',
        refreshToken: 'r',
        accessTokenExpiresAt: exp,
        idToken: 'i',
      ),
    );
    final read = await store.read();
    expect(read!.accessToken, 'a');
    expect(read.refreshToken, 'r');
    expect(read.idToken, 'i');
    expect(read.accessTokenExpiresAt, exp);
  });

  test('clear borra todas las claves', () async {
    final store = SessionStore();
    await store.write(
      StoredSession(
        accessToken: 'a',
        refreshToken: 'r',
        accessTokenExpiresAt: DateTime.utc(2026),
        idToken: 'i',
      ),
    );
    await store.clear();
    expect(await store.read(), isNull);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
  });

  group('almacén ilegible (BAD_DECRYPT tras reinstalar o restaurar copia)', () {
    final broken = PlatformException(
      code: 'Exception encountered',
      message: 'readAll: BadPaddingException BAD_DECRYPT',
    );

    test('read devuelve null y vacía el almacén', () async {
      final storage = _MockStorage();
      when(() => storage.readAll()).thenThrow(broken);
      when(() => storage.deleteAll()).thenAnswer((_) async {});
      expect(await SessionStore(storage).read(), isNull);
      verify(() => storage.deleteAll()).called(1);
    });

    test('si tampoco se puede vaciar, read sigue devolviendo null', () async {
      final storage = _MockStorage();
      when(() => storage.readAll()).thenThrow(broken);
      when(() => storage.deleteAll()).thenThrow(broken);
      expect(await SessionStore(storage).read(), isNull);
    });

    test('un error que no es de la plataforma no se oculta', () async {
      final storage = _MockStorage();
      when(() => storage.readAll()).thenThrow(StateError('bug'));
      expect(SessionStore(storage).read(), throwsStateError);
    });
  });
}
