import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/app.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/core/api/mykcal_api.dart';
import 'package:mykcal/core/auth/auth_controller.dart';
import 'package:mykcal/core/auth/auth_service.dart';
import 'package:mykcal/core/auth/session_store.dart';

final testNow = DateTime.utc(2026, 11, 22, 12);

const meActive = Me(id: 'id-1', displayName: 'Ana', isAdmin: false, active: true);
const meAdmin = Me(id: 'id-2', displayName: 'Erick', isAdmin: true, active: true);
const meDisabled = Me(id: 'id-3', displayName: 'Baja', isAdmin: false, active: false);

TokenSet tokens({String access = 'access-1', String? refresh = 'refresh-1', Duration life = const Duration(minutes: 15)}) =>
    TokenSet(
      accessToken: access,
      refreshToken: refresh,
      idToken: 'id-token',
      expiresAt: testNow.add(life),
    );

class FakeAuthService implements AuthService {
  TokenSet Function() onSignIn = tokens;
  Future<TokenSet> Function(String refreshToken)? onRefresh;
  Future<void> Function(String token)? onRevoke;
  int signInCalls = 0;
  bool lastSignInRegister = false;
  int refreshCalls = 0;
  int revokeCalls = 0;
  int endSessionCalls = 0;
  Object? signInError;

  @override
  Future<TokenSet> signIn({bool register = false}) async {
    signInCalls++;
    lastSignInRegister = register;
    if (signInError != null) throw signInError!;
    return onSignIn();
  }

  @override
  Future<TokenSet> refresh(String refreshToken) async {
    refreshCalls++;
    return onRefresh != null ? onRefresh!(refreshToken) : tokens(access: 'access-2', refresh: 'refresh-2');
  }

  @override
  Future<void> revoke(String token) async {
    revokeCalls++;
    if (onRevoke != null) await onRevoke!(token);
  }

  @override
  Future<void> endSession(String? idTokenHint) async => endSessionCalls++;
}

class FakeApi implements MykcalApi {
  Future<Me> Function() onMe = () async => meActive;
  Future<Me> Function(String code) onRegister = (_) async => meActive;
  Future<InvitationStatus> Function() onInvitation = () async => status();
  Future<InvitationStatus> Function() onRotate = () async => status(code: 'WXYZ6789');
  final registerCodes = <String>[];
  int meCalls = 0;

  @override
  Future<Me> me() {
    meCalls++;
    return onMe();
  }

  @override
  Future<Me> register(String invitationCode) {
    registerCodes.add(invitationCode);
    return onRegister(invitationCode);
  }

  @override
  Future<InvitationStatus> invitation() => onInvitation();

  @override
  Future<InvitationStatus> rotateInvitation() => onRotate();
}

InvitationStatus status({String? code = 'ABCD2345', int active = 3, int free = 47}) =>
    InvitationStatus(code: code, activeAccounts: active, maxAccounts: 50, freeSeats: free);

Future<void> seedSession({String refresh = 'refresh-1', Duration life = const Duration(minutes: 15)}) =>
    SessionStore().write(StoredSession(
      accessToken: 'access-1',
      refreshToken: refresh,
      accessTokenExpiresAt: testNow.add(life),
      idToken: 'id-token',
    ));

class Harness {
  Harness({FakeAuthService? auth, FakeApi? api})
      : auth = auth ?? FakeAuthService(),
        api = api ?? FakeApi() {
    FlutterSecureStorage.setMockInitialValues({});
  }

  final FakeAuthService auth;
  final FakeApi api;
  Duration signOutDeadline = const Duration(seconds: 5);

  List<Override> get overrides => [
        authServiceProvider.overrideWithValue(auth),
        mykcalApiProvider.overrideWithValue(api),
        authClockProvider.overrideWithValue(() => testNow),
        signOutDeadlineProvider.overrideWithValue(signOutDeadline),
      ];

  ProviderContainer container() {
    final c = ProviderContainer(overrides: overrides);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(overrides: overrides, child: const MykcalApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Espera a que el controlador salga del estado de carga.
Future<AccountState> settled(ProviderContainer c) async {
  final value = await c.read(authControllerProvider.future);
  return c.read(authControllerProvider).valueOrNull ?? value;
}

Completer<T> never<T>() => Completer<T>();
