import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mykcal/app.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/core/api/mykcal_api.dart';
import 'package:mykcal/core/auth/auth_controller.dart';
import 'package:mykcal/core/auth/auth_service.dart';
import 'package:mykcal/core/auth/session_store.dart';
import 'package:mykcal/core/config/download_link.dart';
import 'package:mykcal/core/theme/app_theme.dart';
import 'package:mykcal/features/ai_key/onboarding_flag.dart';
import 'package:mykcal/features/diary/diary_day_controller.dart';
import 'package:mykcal/features/photo/photo_picker.dart';
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

/// Plátano genérico con la vitamina D sin dato (FR-016).
Food sampleFood({
  String id = 'food-1',
  String name = 'Plátano, crudo',
  FoodKind kind = FoodKind.generic,
  bool isMine = false,
  double? servingSize,
  String baseUnit = 'g',
  String? brand,
  String? barcode,
  Nutrients per100 = const Nutrients(
    kcal: 90,
    proteinG: 1.1,
    carbsG: 19.7,
    fatG: 0.3,
    fiberG: 2,
    sodiumMg: 1,
    potassiumMg: 358,
    calciumMg: 5,
    ironMg: 0.3,
    magnesiumMg: 27,
    vitaminCMg: 8.7,
  ),
}) => Food(
  id: id,
  kind: kind,
  name: name,
  brand: brand,
  barcode: barcode,
  baseUnit: baseUnit,
  per100: per100,
  servingSize: servingSize,
  isMine: isMine,
  source: switch (kind) {
    FoodKind.generic => 'ciqual',
    FoodKind.packaged => 'off',
    FoodKind.custom => 'user',
  },
);

FoodSummary sampleSummary({
  String id = 'food-1',
  String name = 'Plátano, crudo',
  FoodKind kind = FoodKind.generic,
  bool isMine = false,
  double kcal = 90,
  String? brand,
  String baseUnit = 'g',
}) => FoodSummary(
  id: id,
  kind: kind,
  name: name,
  brand: brand,
  baseUnit: baseUnit,
  kcal: kcal,
  isMine: isMine,
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

class AddEntryCall {
  const AddEntryCall({
    required this.date,
    required this.meal,
    required this.foodId,
    required this.utcOffsetMin,
    this.quantity,
    this.servings,
  });

  final DateTime date;
  final Meal meal;
  final String foodId;
  final double? quantity;
  final double? servings;
  final int utcOffsetMin;
}

class AnalyzeCall {
  const AnalyzeCall({
    required this.photoPath,
    required this.meal,
    required this.date,
    this.description,
    this.totalGrams,
  });

  final String photoPath;
  final Meal meal;
  final DateTime date;
  final String? description;
  final int? totalGrams;
}

class CopyMealCall {
  const CopyMealCall({
    required this.sourceDate,
    required this.sourceMeal,
    required this.targetDate,
    required this.targetMeal,
    required this.utcOffsetMin,
  });

  final DateTime sourceDate;
  final Meal sourceMeal;
  final DateTime targetDate;
  final Meal targetMeal;
  final int utcOffsetMin;
}

class UpdateEntryCall {
  const UpdateEntryCall({
    required this.id,
    required this.utcOffsetMin,
    this.meal,
    this.quantity,
    this.servings,
  });

  final String id;
  final Meal? meal;
  final double? quantity;
  final double? servings;
  final int utcOffsetMin;
}

/// Valores de una entrada o de un total, con los opcionales sin dato salvo que se pasen.
Nutrients amounts({
  double kcal = 0,
  double proteinG = 0,
  double carbsG = 0,
  double fatG = 0,
  double? fiberG,
  double? sodiumMg,
  double? potassiumMg,
  double? calciumMg,
  double? ironMg,
  double? magnesiumMg,
  double? vitaminDUg,
  double? vitaminCMg,
}) => Nutrients(
  kcal: kcal,
  proteinG: proteinG,
  carbsG: carbsG,
  fatG: fatG,
  fiberG: fiberG,
  sodiumMg: sodiumMg,
  potassiumMg: potassiumMg,
  calciumMg: calciumMg,
  ironMg: ironMg,
  magnesiumMg: magnesiumMg,
  vitaminDUg: vitaminDUg,
  vitaminCMg: vitaminCMg,
);

/// Entrada de ejemplo: 60 g de un pan de 250 kcal/100 g (150 kcal).
DiaryEntry sampleEntry({
  String id = 'e1',
  Meal meal = Meal.breakfast,
  String name = 'Pan integral',
  String? brand,
  double quantity = 60,
  double? servings,
  double? servingSize,
  Nutrients? per100,
  Nutrients? values,
}) {
  final base =
      per100 ??
      const Nutrients(kcal: 250, proteinG: 9, carbsG: 42, fatG: 3, fiberG: 7);
  final factor = quantity / 100;
  return DiaryEntry(
    id: id,
    meal: meal,
    foodId: 'food-$id',
    foodKind: FoodKind.generic,
    foodName: name,
    foodBrand: brand,
    baseUnit: 'g',
    servingSize: servingSize,
    per100: base,
    quantity: quantity,
    servings: servings,
    values:
        values ??
        amounts(
          kcal: (base.kcal * factor).roundToDouble(),
          proteinG: base.proteinG * factor,
          carbsG: base.carbsG * factor,
          fatG: base.fatG * factor,
          fiberG: base.fiberG == null ? null : base.fiberG! * factor,
        ),
    incomplete: [if (base.fiberG == null) 'fiber_g'],
  );
}

/// Alimento de Recientes o Favoritos con su cantidad sugerida (005).
QuickFood sampleQuick({
  String id = 'food-1',
  String name = 'Pan de molde',
  String? brand,
  double quantity = 60,
  double? servings,
  double? servingSize,
  bool favorite = false,
  DateTime? lastUsedAt,
}) => QuickFood(
  food: sampleFood(
    id: id,
    name: name,
    brand: brand,
    servingSize: servingSize ?? (servings == null ? null : quantity / servings),
    per100: const Nutrients(kcal: 250, proteinG: 8, carbsG: 46, fatG: 3.5),
  ),
  suggestedQuantity: quantity,
  suggestedServings: servings,
  lastUsedAt: lastUsedAt ?? DateTime.utc(2026, 11, 21, 8),
  isFavorite: favorite,
);

const _mealOrder = Meal.values;

/// Día de ejemplo con el objetivo de [sampleValues] y las entradas repartidas por comida.
/// Los totales se calculan con los valores de las entradas, sin redondear de más.
DiaryDay sampleDay({
  DateTime? date,
  TargetValues target = sampleValues,
  List<DiaryEntry> entries = const [],
  List<String> incomplete = const [],
}) {
  double sum(double Function(Nutrients) f, Iterable<DiaryEntry> es) =>
      es.fold(0.0, (a, e) => a + f(e.values));
  NutrientTotals totalsOf(Iterable<DiaryEntry> es, List<String> inc) =>
      NutrientTotals(
        consumed: amounts(
          kcal: sum((n) => n.kcal, es),
          proteinG: sum((n) => n.proteinG, es),
          carbsG: sum((n) => n.carbsG, es),
          fatG: sum((n) => n.fatG, es),
          fiberG: sum((n) => n.fiberG ?? 0, es),
          sodiumMg: sum((n) => n.sodiumMg ?? 0, es),
          potassiumMg: sum((n) => n.potassiumMg ?? 0, es),
          calciumMg: sum((n) => n.calciumMg ?? 0, es),
          ironMg: sum((n) => n.ironMg ?? 0, es),
          magnesiumMg: sum((n) => n.magnesiumMg ?? 0, es),
          vitaminDUg: sum((n) => n.vitaminDUg ?? 0, es),
          vitaminCMg: sum((n) => n.vitaminCMg ?? 0, es),
        ),
        incomplete: inc,
      );
  final day = totalsOf(entries, incomplete);
  final t = target.toJson();
  final c = day.consumed.toJson();
  return DiaryDay(
    date: date ?? DateTime(2026, 11, 22),
    target: target,
    totals: day,
    remaining: {
      for (final k in t.keys)
        k: (t[k] as int) - ((c[k] as num?)?.toDouble() ?? 0),
    },
    meals: [
      for (final m in _mealOrder)
        DiaryMeal(
          meal: m,
          entries: entries.where((e) => e.meal == m).toList(),
          totals: totalsOf(entries.where((e) => e.meal == m), const []),
        ),
    ],
  );
}

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
  Future<List<FoodSummary>> Function(String query) onSearchFoods = (_) async =>
      const [];
  Future<Food> Function(String id) onFood = (_) async => sampleFood();
  Future<BarcodeLookup> Function(String code) onBarcode = (code) async =>
      BarcodeLookup(
        result: BarcodeResult.found,
        code: code,
        food: sampleFood(),
      );
  Future<List<FoodSummary>> Function() onCustomFoods = () async => const [];
  Future<CustomFoodSaved> Function(CustomFoodInput input) onCreateCustom = (
    _,
  ) async => CustomFoodSaved(food: sampleFood(), warnings: const []);
  Future<CustomFoodSaved> Function(String id, CustomFoodInput input)
  onUpdateCustom = (_, _) async =>
      CustomFoodSaved(food: sampleFood(), warnings: const []);
  Future<void> Function(String id) onDeleteCustom = (_) async {};
  Future<DiaryDay> Function(DateTime date, int offset) onDiaryDay = (
    date,
    _,
  ) async => sampleDay(date: date);
  Future<DiaryDay> Function(AddEntryCall call) onAddEntry = (call) async =>
      sampleDay(date: call.date);

  /// Id que devuelve `addEntry` como si viniera de la cabecera `Location`.
  String addedEntryId = 'entry-new';
  Future<List<QuickFood>> Function() onRecentFoods = () async => const [];
  Future<List<QuickFood>> Function() onFavoriteFoods = () async => const [];
  Future<void> Function(String foodId) onAddFavorite = (_) async {};
  Future<void> Function(String foodId) onRemoveFavorite = (_) async {};
  Future<List<CopySourceDay>> Function(DateTime date, Meal meal) onCopySources =
      (_, _) async => const [];
  Future<DiaryCopyResult> Function(CopyMealCall call) onCopyMeal =
      (call) async => DiaryCopyResult(
        copyId: 'copy-1',
        entryIds: const ['c1'],
        day: sampleDay(date: call.targetDate),
      );
  Future<DiaryDay> Function(String copyId, int offset) onUndoCopy = (
    _,
    _,
  ) async => sampleDay();
  final favoriteAdds = <String>[];
  final favoriteRemoves = <String>[];
  final copyCalls = <CopyMealCall>[];
  final undoneCopies = <String>[];
  int recentCalls = 0;
  int favoriteCalls = 0;
  Future<DiaryDay> Function(UpdateEntryCall call) onUpdateEntry = (_) async =>
      sampleDay();
  Future<DiaryDay> Function(String id, int offset) onDeleteEntry = (
    _,
    _,
  ) async => sampleDay();
  Future<DiaryDay> Function(String id, int offset) onRestoreEntry = (
    _,
    _,
  ) async => sampleDay();
  final diaryRequests = <(DateTime, int)>[];
  final addedEntries = <AddEntryCall>[];
  final updatedEntries = <UpdateEntryCall>[];
  final deletedEntries = <String>[];
  final restoredEntries = <String>[];
  final searchQueries = <String>[];
  final barcodeCodes = <String>[];
  final createdFoods = <CustomFoodInput>[];
  final updatedFoods = <String, CustomFoodInput>{};
  final deletedFoods = <String>[];
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
  Future<List<FoodSummary>> searchFoods(String query) {
    searchQueries.add(query);
    return onSearchFoods(query);
  }

  @override
  Future<Food> food(String id) => onFood(id);

  @override
  Future<DiaryDay> diaryDay(DateTime date, int utcOffsetMin) {
    diaryRequests.add((date, utcOffsetMin));
    return onDiaryDay(date, utcOffsetMin);
  }

  @override
  Future<AddedEntry> addEntry({
    required DateTime date,
    required Meal meal,
    required String foodId,
    double? quantity,
    double? servings,
    required int utcOffsetMin,
  }) async {
    final call = AddEntryCall(
      date: date,
      meal: meal,
      foodId: foodId,
      quantity: quantity,
      servings: servings,
      utcOffsetMin: utcOffsetMin,
    );
    addedEntries.add(call);
    return AddedEntry(day: await onAddEntry(call), entryId: addedEntryId);
  }

  @override
  Future<List<QuickFood>> recentFoods() {
    recentCalls++;
    return onRecentFoods();
  }

  @override
  Future<List<QuickFood>> favoriteFoods() {
    favoriteCalls++;
    return onFavoriteFoods();
  }

  @override
  Future<void> addFavorite(String foodId) {
    favoriteAdds.add(foodId);
    return onAddFavorite(foodId);
  }

  @override
  Future<void> removeFavorite(String foodId) {
    favoriteRemoves.add(foodId);
    return onRemoveFavorite(foodId);
  }

  @override
  Future<List<CopySourceDay>> copySources(
    DateTime targetDate,
    Meal targetMeal,
  ) => onCopySources(targetDate, targetMeal);

  @override
  Future<DiaryCopyResult> copyMeal({
    required DateTime sourceDate,
    required Meal sourceMeal,
    required DateTime targetDate,
    required Meal targetMeal,
    required int utcOffsetMin,
  }) {
    final call = CopyMealCall(
      sourceDate: sourceDate,
      sourceMeal: sourceMeal,
      targetDate: targetDate,
      targetMeal: targetMeal,
      utcOffsetMin: utcOffsetMin,
    );
    copyCalls.add(call);
    return onCopyMeal(call);
  }

  @override
  Future<DiaryDay> undoCopy(String copyId, int utcOffsetMin) {
    undoneCopies.add(copyId);
    return onUndoCopy(copyId, utcOffsetMin);
  }

  @override
  Future<DiaryDay> updateEntry(
    String id, {
    Meal? meal,
    double? quantity,
    double? servings,
    required int utcOffsetMin,
  }) {
    final call = UpdateEntryCall(
      id: id,
      meal: meal,
      quantity: quantity,
      servings: servings,
      utcOffsetMin: utcOffsetMin,
    );
    updatedEntries.add(call);
    return onUpdateEntry(call);
  }

  @override
  Future<DiaryDay> deleteEntry(String id, int utcOffsetMin) {
    deletedEntries.add(id);
    return onDeleteEntry(id, utcOffsetMin);
  }

  @override
  Future<DiaryDay> restoreEntry(String id, int utcOffsetMin) {
    restoredEntries.add(id);
    return onRestoreEntry(id, utcOffsetMin);
  }

  @override
  Future<BarcodeLookup> lookupBarcode(String code) {
    barcodeCodes.add(code);
    return onBarcode(code);
  }

  @override
  Future<List<FoodSummary>> customFoods() => onCustomFoods();

  @override
  Future<CustomFoodSaved> createCustomFood(CustomFoodInput input) {
    createdFoods.add(input);
    return onCreateCustom(input);
  }

  @override
  Future<CustomFoodSaved> updateCustomFood(String id, CustomFoodInput input) {
    updatedFoods[id] = input;
    return onUpdateCustom(id, input);
  }

  @override
  Future<void> deleteCustomFood(String id) {
    deletedFoods.add(id);
    return onDeleteCustom(id);
  }

  Future<AiKeyStatus?> Function() onAiKey = () async => null;
  Future<AiKeyStatus> Function(String rawKey) onSaveAiKey = (_) async =>
      AiKeyStatus(provider: 'gemini', configuredAt: DateTime.utc(2026, 11, 25));
  Future<void> Function() onDeleteAiKey = () async {};
  Future<PhotoAnalysisResult> Function(AnalyzeCall call) onAnalyzePhoto = (
    _,
  ) async => const PhotoAnalysisResult(items: []);
  final savedAiKeys = <String>[];
  final analyzeCalls = <AnalyzeCall>[];
  int deleteAiKeyCalls = 0;

  @override
  Future<AiKeyStatus?> aiKey() => onAiKey();

  @override
  Future<AiKeyStatus> saveAiKey(String rawKey) {
    savedAiKeys.add(rawKey);
    return onSaveAiKey(rawKey);
  }

  @override
  Future<void> deleteAiKey() {
    deleteAiKeyCalls++;
    return onDeleteAiKey();
  }

  @override
  Future<PhotoAnalysisResult> analyzePhoto({
    required String photoPath,
    required Meal meal,
    required DateTime date,
    String? description,
    int? totalGrams,
  }) {
    final call = AnalyzeCall(
      photoPath: photoPath,
      meal: meal,
      date: date,
      description: description,
      totalGrams: totalGrams,
    );
    analyzeCalls.add(call);
    return onAnalyzePhoto(call);
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
    SharedPreferences.setMockInitialValues({});
  }

  final FakeAuthService auth;
  final FakeApi api;
  Duration signOutDeadline = const Duration(seconds: 5);

  /// Si ya vio el paso opcional de la clave de IA (006). Por defecto sí: las pruebas arrancan en
  /// el inicio.
  bool aiKeyStepSeen = true;
  final picker = FakePhotoPicker();

  /// «Ahora» del diario; las pruebas lo cambian para simular el paso de la medianoche.
  DateTime diaryNow = testNow;

  List<Override> get overrides => [
    authServiceProvider.overrideWithValue(auth),
    mykcalApiProvider.overrideWithValue(api),
    authClockProvider.overrideWithValue(() => testNow),
    diaryNowProvider.overrideWithValue(() => diaryNow),
    signOutDeadlineProvider.overrideWithValue(signOutDeadline),
    photoPickerProvider.overrideWithValue(picker),
    aiKeyStepSeenReaderProvider.overrideWithValue(() async => aiKeyStepSeen),
    aiKeyStepMarkerProvider.overrideWithValue(() async => aiKeyStepSeen = true),
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const MykcalApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // El paso opcional de la clave de IA lee su bandera antes de mostrar el inicio.
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

/// Foto de ejemplo de un borrador (la ruta no necesita existir).
const photoPath = '/tmp/mykcal-test-photo.jpg';

/// Propuesta de la IA con un alimento emparejado y otro sin pareja.
PhotoAnalysisResult sampleProposal({bool unmatched = true}) =>
    PhotoAnalysisResult(
      items: [
        ProposedItem(
          aiName: 'Arroz blanco cocido',
          aiGrams: 150,
          flagged: false,
          matchedFood: sampleSummary(id: 'rice', name: 'Arroz, blanco, cocido'),
          matchedSimilarity: 0.9,
          kcal: 195,
          proteinG: 4,
          carbsG: 42,
          fatG: 0.5,
        ),
        if (unmatched)
          const ProposedItem(
            aiName: 'Yogur griego con miel',
            aiGrams: 120,
            flagged: false,
          ),
      ],
    );

/// Fotos sin cámara: devuelve lo que se le diga.
class FakePhotoPicker implements PhotoPicker {
  String? path = photoPath;
  bool denyCamera = false;
  final sources = <PhotoSource>[];

  @override
  Future<String?> pick(PhotoSource source) async {
    sources.add(source);
    if (denyCamera && source == PhotoSource.camera) {
      throw const PhotoPermissionDenied();
    }
    return path;
  }
}
