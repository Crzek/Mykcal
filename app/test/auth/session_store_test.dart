import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/auth/session_store.dart';

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
}
