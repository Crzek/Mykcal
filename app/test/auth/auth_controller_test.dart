import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/auth/auth_controller.dart';
import 'package:mykcal/core/auth/auth_service.dart';
import 'package:mykcal/core/auth/session_store.dart';

import '../helpers/fakes.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());

  test('inicio correcto guarda la sesión y carga la cuenta (US2-1)', () async {
    final c = h.container();
    expect(await settled(c), isA<SignedOut>());
    await c.read(authControllerProvider.notifier).signIn();
    final state = c.read(authControllerProvider).value;
    expect(state, isA<Active>());
    expect((state as Active).me.displayName, 'Ana');
    expect((await SessionStore().read())!.refreshToken, 'refresh-1');
  });

  test('«Crear cuenta» pide la página de registro', () async {
    final c = h.container();
    await settled(c);
    await c.read(authControllerProvider.notifier).signIn(register: true);
    expect(h.auth.lastSignInRegister, isTrue);
  });

  test('cancelar el navegador no es un error', () async {
    h.auth.signInError = const SignInCancelled();
    final c = h.container();
    await settled(c);
    await c.read(authControllerProvider.notifier).signIn();
    final state = c.read(authControllerProvider).value as SignedOut;
    expect(state.notice, isNull);
    expect(state.busy, isFalse);
  });

  test('errores de acceso → avisos', () async {
    final c = h.container();
    await settled(c);
    h.auth.signInError = const AuthServiceUnavailable();
    await c.read(authControllerProvider.notifier).signIn();
    expect(
      (c.read(authControllerProvider).value as SignedOut).notice,
      AccessNotice.unavailable,
    );
    h.auth.signInError = const SignInFailed();
    await c.read(authControllerProvider.notifier).signIn();
    expect(
      (c.read(authControllerProvider).value as SignedOut).notice,
      AccessNotice.signInFailed,
    );
  });

  test('sin refresh token no se guarda la sesión', () async {
    h.auth.onSignIn = () => tokens(refresh: null);
    final c = h.container();
    await settled(c);
    await c.read(authControllerProvider.notifier).signIn();
    expect(c.read(authControllerProvider).value, isA<SignedOut>());
    expect(await SessionStore().read(), isNull);
  });

  test('renovación transparente cuando queda menos del margen; guarda el refresh rotado', () async {
    await seedSession(life: const Duration(seconds: 30));
    final c = h.container();
    await settled(c);
    final token = await c
        .read(authControllerProvider.notifier)
        .validAccessToken();
    expect(token, 'access-2');
    expect(h.auth.refreshCalls, 1);
    expect((await SessionStore().read())!.refreshToken, 'refresh-2');
  });

  test('con el token vigente no renueva', () async {
    await seedSession();
    final c = h.container();
    await settled(c);
    expect(
      await c.read(authControllerProvider.notifier).validAccessToken(),
      'access-1',
    );
    expect(h.auth.refreshCalls, 0);
  });

  test('renovaciones simultáneas comparten una sola llamada', () async {
    await seedSession(life: const Duration(seconds: 10));
    final gate = Completer<TokenSet>();
    h.auth.onRefresh = (_) => gate.future;
    final c = h.container();
    await settled(c);
    final n = c.read(authControllerProvider.notifier);
    final futures = [
      n.validAccessToken(),
      n.validAccessToken(),
      n.forceRefresh(),
    ];
    await Future<void>.delayed(Duration.zero);
    gate.complete(tokens(access: 'access-9', refresh: 'refresh-9'));
    expect(await Future.wait(futures), ['access-9', 'access-9', 'access-9']);
    expect(h.auth.refreshCalls, 1);
  });

  test(
    'refresh rechazado → null y la sesión se conserva hasta markExpired',
    () async {
      await seedSession();
      h.auth.onRefresh = (_) async => throw const RefreshRejected();
      final c = h.container();
      await settled(c);
      final n = c.read(authControllerProvider.notifier);
      expect(await n.forceRefresh(), isNull);
      await n.markExpired();
      expect(
        (c.read(authControllerProvider).value as SignedOut).notice,
        AccessNotice.sessionExpired,
      );
      expect(await SessionStore().read(), isNull);
    },
  );

  test(
    'fallo temporal de renovación lanza NetworkFailure y no borra la sesión',
    () async {
      await seedSession();
      h.auth.onRefresh = (_) async => throw const RefreshFailed();
      final c = h.container();
      await settled(c);
      await expectLater(
        c.read(authControllerProvider.notifier).forceRefresh(),
        throwsA(isA<NetworkFailure>()),
      );
      expect(await SessionStore().read(), isNotNull);
    },
  );

  test('cerrar sesión revoca, borra los tokens y cierra la sesión del navegador (US2-3)', () async {
    await seedSession();
    final c = h.container();
    await settled(c);
    await c.read(authControllerProvider.notifier).signOut();
    expect(c.read(authControllerProvider).value, isA<SignedOut>());
    expect(await SessionStore().read(), isNull);
    expect(h.auth.revokeCalls, 2);
    expect(h.auth.endSessionCalls, 1);
  });

  test('cerrar sesión borra los tokens aunque falle la revocación', () async {
    await seedSession();
    h.auth.onRevoke = (_) async => throw Exception('sin red');
    final c = h.container();
    await settled(c);
    await c.read(authControllerProvider.notifier).signOut();
    expect(await SessionStore().read(), isNull);
  });

  test(
    'cerrar sesión no espera más del plazo si Zitadel no responde',
    () async {
      await seedSession();
      h.signOutDeadline = const Duration(milliseconds: 50);
      h.auth.onRevoke = (_) => never<void>().future;
      final c = h.container();
      await settled(c);
      await c
          .read(authControllerProvider.notifier)
          .signOut()
          .timeout(const Duration(seconds: 2));
      expect(await SessionStore().read(), isNull);
      expect(c.read(authControllerProvider).value, isA<SignedOut>());
    },
  );
}
