import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/app.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/core/api/mykcal_api.dart';
import 'package:mykcal/core/auth/auth_controller.dart';
import 'package:mykcal/core/auth/auth_service.dart';
import 'package:mykcal/core/auth/session_store.dart';
import 'package:mykcal/core/config/download_link.dart';
import 'package:mykcal/core/theme/app_theme.dart';
import 'package:mykcal/l10n/app_localizations.dart';

final testNow = DateTime.utc(2026, 11, 22, 12);

const meActive = Me(
  id: 'id-1',
  displayName: 'Ana',
  isAdmin: false,
  active: true,
);
const meAdmin = Me(
  id: 'id-2',
  displayName: 'Erick',
  isAdmin: true,
  active: true,
);
const meDisabled = Me(
  id: 'id-3',
  displayName: 'Baja',
  isAdmin: false,
  active: false,
);

const meNeedsConsent = Me(
  id: 'id-4',
  displayName: 'Nueva',
  isAdmin: false,
  active: true,
  onboarding: Onboarding.consent,
);
const meNeedsProfile = Me(
  id: 'id-5',
  displayName: 'Nueva',
  isAdmin: false,
  active: true,
  onboarding: Onboarding.profile,
);

/// Ejemplo de la spec: hombre, 30 años, 180 cm, 80 kg, moderada, mantener (US2.2).
const sampleValues = TargetValues(
  kcal: 2759,
  proteinG: 144,
  carbsG: 373,
  fatG: 77,
  fiberG: 30,
  sodiumMg: 2000,
  potassiumMg: 3500,
  calciumMg: 1000,
  ironMg: 8,
  magnesiumMg: 400,
  vitaminDUg: 15,
  vitaminCMg: 90,
);
const losingValues = TargetValues(
  kcal: 2207,
  proteinG: 176,
  carbsG: 238,
  fatG: 61,
  fiberG: 30,
  sodiumMg: 2000,
  potassiumMg: 3500,
  calciumMg: 1000,
  ironMg: 8,
  magnesiumMg: 400,
  vitaminDUg: 15,
  vitaminCMg: 90,
);

DailyTarget sampleTarget({
  TargetValues values = sampleValues,
  bool manual = false,
  List<String> notices = const [],
  String sex = 'male',
}) => DailyTarget(
  values: values,
  manual: manual,
  calculation: TargetCalculation(sex: sex, notices: notices),
);

const sampleProfile = Profile(
  age: 30,
  sex: 'male',
  heightCm: 180,
  weightKg: 80,
  activityLevel: 'moderate',
  goal: 'maintain',
);

ProfileSaved savedProfile({
  RecalculationStatus status = RecalculationStatus.created,
  DailyTarget? target,
  TargetValues? previous,
  TargetValues? proposed,
}) => ProfileSaved(
  profile: sampleProfile,
  target: target ?? sampleTarget(),
  status: status,
  previous: previous,
  proposed: proposed,
);

TokenSet tokens({
  String access = 'access-1',
  String? refresh = 'refresh-1',
  Duration life = const Duration(minutes: 15),
}) => TokenSet(
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
    return onRefresh != null
        ? onRefresh!(refreshToken)
        : tokens(access: 'access-2', refresh: 'refresh-2');
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
  Future<InvitationStatus> Function() onRotate = () async =>
      status(code: 'WXYZ6789');
  Future<void> Function(String version) onConsent = (_) async {};
  Future<Profile> Function() onProfile = () async => sampleProfile;
  Future<ProfileSaved> Function(ProfileInput input) onSaveProfile = (_) async =>
      savedProfile();
  Future<DailyTarget> Function() onTarget = () async => sampleTarget();
  Future<DailyTarget> Function(TargetValues values) onSaveTarget = (v) async =>
      sampleTarget(values: v, manual: true);
  Future<DailyTarget> Function() onRecalculate = () async => sampleTarget();
  Future<void> Function() onDeactivate = () async {};
  final registerCodes = <String>[];
  final consentVersions = <String>[];
  final savedProfiles = <ProfileInput>[];
  final savedTargets = <TargetValues>[];
  int recalculateCalls = 0;
  int deactivateCalls = 0;
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
  Future<void> acceptConsent(String textVersion) {
    consentVersions.add(textVersion);
    return onConsent(textVersion);
  }

  @override
  Future<Profile> profile() => onProfile();

  @override
  Future<ProfileSaved> saveProfile(ProfileInput input) {
    savedProfiles.add(input);
    return onSaveProfile(input);
  }

  @override
  Future<DailyTarget> target() => onTarget();

  @override
  Future<DailyTarget> saveTarget(TargetValues values) {
    savedTargets.add(values);
    return onSaveTarget(values);
  }

  @override
  Future<DailyTarget> recalculateTarget() {
    recalculateCalls++;
    return onRecalculate();
  }

  @override
  Future<void> deactivate() {
    deactivateCalls++;
    return onDeactivate();
  }

  @override
  Future<InvitationStatus> invitation() => onInvitation();

  @override
  Future<InvitationStatus> rotateInvitation() => onRotate();
}

InvitationStatus status({
  String? code = 'ABCD2345',
  int active = 3,
  int free = 47,
}) => InvitationStatus(
  code: code,
  activeAccounts: active,
  maxAccounts: 50,
  freeSeats: free,
);

Future<void> seedSession({
  String refresh = 'refresh-1',
  Duration life = const Duration(minutes: 15),
}) => SessionStore().write(
  StoredSession(
    accessToken: 'access-1',
    refreshToken: refresh,
    accessTokenExpiresAt: testNow.add(life),
    idToken: 'id-token',
  ),
);

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
    downloadLinkProvider.overrideWithValue(
      'https://mykcal-bk-api.cruzerick.com/descargar/mykcal.apk',
    ),
  ];

  ProviderContainer container() {
    final c = ProviderContainer(overrides: overrides);
    addTearDown(c.dispose);
    return c;
  }

  /// Pinta una pantalla suelta con los mismos proveedores, tema y textos que la app.
  Future<void> pumpScreen(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const MykcalApp()),
    );
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

/// Pantalla alta para que los formularios largos construyan todos sus campos.
Future<void> tallScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
