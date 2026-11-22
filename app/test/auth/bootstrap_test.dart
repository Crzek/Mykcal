import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/auth/auth_controller.dart';

import '../helpers/fakes.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());

  test('sin tokens → signedOut sin llamar al API', () async {
    final c = h.container();
    expect(await settled(c), isA<SignedOut>());
    expect(h.api.meCalls, 0);
  });

  test('/me activa → active', () async {
    await seedSession();
    expect(await settled(h.container()), isA<Active>());
  });

  test('/me desactivada → disabled', () async {
    await seedSession();
    h.api.onMe = () async => meDisabled;
    expect(await settled(h.container()), isA<Disabled>());
  });

  test('ACCOUNT_NOT_REGISTERED → needsRegistration', () async {
    await seedSession();
    h.api.onMe = () async => throw const ApiError('ACCOUNT_NOT_REGISTERED', 404);
    expect(await settled(h.container()), isA<NeedsRegistration>());
  });

  test('sesión no renovable → signedOut con aviso y tokens borrados', () async {
    await seedSession();
    h.api.onMe = () async => throw const SessionExpired();
    final state = await settled(h.container());
    expect((state as SignedOut).notice, AccessNotice.sessionExpired);
  });

  test('sin red → error de conexión «offline» y reintento (FR-015)', () async {
    await seedSession();
    h.api.onMe = () async => throw const NetworkFailure();
    final c = h.container();
    expect((await settled(c) as ConnectionError).offline, isTrue);
    h.api.onMe = () async => meActive;
    await c.read(authControllerProvider.notifier).retry();
    expect(c.read(authControllerProvider).value, isA<Active>());
  });

  test('5xx → error de conexión no «offline»', () async {
    await seedSession();
    h.api.onMe = () async => throw const ServerFailure();
    expect((await settled(h.container()) as ConnectionError).offline, isFalse);
  });
}
