import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../format/dates.dart';
import 'api_errors.dart';
import 'models.dart';

/// Contrato del API (contracts/openapi.yaml). Las pruebas sustituyen esta interfaz.
abstract class MykcalApi {
  Future<Me> me();
  Future<Me> register(String invitationCode);
  Future<InvitationStatus> invitation();
  Future<InvitationStatus> rotateInvitation();
  Future<void> acceptConsent(String textVersion);
  Future<Profile> profile();
  Future<ProfileSaved> saveProfile(ProfileInput input);
  Future<DailyTarget> target();
  Future<DailyTarget> saveTarget(TargetValues values);
  Future<DailyTarget> recalculateTarget();
  Future<void> deactivate();
  Future<List<FoodSummary>> searchFoods(String query);
  Future<Food> food(String id);
  Future<BarcodeLookup> lookupBarcode(String code);
  Future<List<FoodSummary>> customFoods();
  Future<CustomFoodSaved> createCustomFood(CustomFoodInput input);
  Future<CustomFoodSaved> updateCustomFood(String id, CustomFoodInput input);
  Future<void> deleteCustomFood(String id);

  /// Diario (004). `utcOffsetMin` es el desfase de la zona del móvil al final del día afectado
  /// (research R3). Todas devuelven el día completo y recalculado (R9).
  Future<DiaryDay> diaryDay(DateTime date, int utcOffsetMin);
  Future<AddedEntry> addEntry({
    required DateTime date,
    required Meal meal,
    required String foodId,
    double? quantity,
    double? servings,
    required int utcOffsetMin,
  });
  Future<DiaryDay> updateEntry(
    String id, {
    Meal? meal,
    double? quantity,
    double? servings,
    required int utcOffsetMin,
  });
  Future<DiaryDay> deleteEntry(String id, int utcOffsetMin);
  Future<DiaryDay> restoreEntry(String id, int utcOffsetMin);

  /// Registro rápido (005): recientes, favoritos y copiar una comida de otro día.
  Future<List<QuickFood>> recentFoods();
  Future<List<QuickFood>> favoriteFoods();
  Future<void> addFavorite(String foodId);
  Future<void> removeFavorite(String foodId);
  Future<List<CopySourceDay>> copySources(DateTime targetDate, Meal targetMeal);
  Future<DiaryCopyResult> copyMeal({
    required DateTime sourceDate,
    required Meal sourceMeal,
    required DateTime targetDate,
    required Meal targetMeal,
    required int utcOffsetMin,
  });
  Future<DiaryDay> undoCopy(String copyId, int utcOffsetMin);

  /// Clave de IA y registro por foto (006). `aiKey` devuelve `null` si no hay clave.
  Future<AiKeyStatus?> aiKey();
  Future<AiKeyStatus> saveAiKey(String rawKey);
  Future<void> deleteAiKey();
  Future<PhotoAnalysisResult> analyzePhoto({
    required String photoPath,
    required Meal meal,
    required DateTime date,
    String? description,
    int? totalGrams,
  });

  /// Peso y recálculo del objetivo (007). `utcOffsetMin` fija el «hoy» local del móvil.
  Future<List<WeightEntry>> weightEntries();
  Future<WeightEntry> saveWeight(DateTime day, double kg, int utcOffsetMin);
  Future<WeightEntry> updateWeight(DateTime day, double kg, int utcOffsetMin);
  Future<void> deleteWeight(DateTime day, int utcOffsetMin);

  /// `period`: `p30`, `p90` o `all`.
  Future<WeightChart> weightChart(String period, int utcOffsetMin);
  Future<RecalcProposal> recalcProposal(int utcOffsetMin);
  Future<DailyTarget> acceptRecalc(int utcOffsetMin);
  Future<void> ignoreRecalc(int utcOffsetMin);
}

typedef TokenSource = Future<String?> Function();

/// Cliente dio: añade el bearer, renueva una vez ante un 401 y traduce los errores.
class HttpMykcalApi implements MykcalApi {
  HttpMykcalApi({
    required this.dio,
    required this.accessToken,
    required this.refreshToken,
  });

  static const requestTimeout = Duration(seconds: 10);

  static Dio buildDio(String baseUrl) => Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: requestTimeout,
      sendTimeout: requestTimeout,
      receiveTimeout: requestTimeout,
    ),
  );

  final Dio dio;

  /// Token vigente (lo renueva si le queda poco); `null` si no hay sesión.
  final TokenSource accessToken;

  /// Fuerza una renovación; `null` si no se pudo (sesión caducada o revocada).
  final TokenSource refreshToken;

  @override
  Future<Me> me() async => Me.fromJson(await _json('GET', '/v1/me'));

  @override
  Future<Me> register(String invitationCode) async => Me.fromJson(
    await _json(
      'POST',
      '/v1/registration',
      data: {'invitation_code': invitationCode},
    ),
  );

  @override
  Future<InvitationStatus> invitation() async =>
      InvitationStatus.fromJson(await _json('GET', '/v1/admin/invitation'));

  @override
  Future<InvitationStatus> rotateInvitation() async =>
      InvitationStatus.fromJson(
        await _json('POST', '/v1/admin/invitation/rotate'),
      );

  @override
  Future<void> acceptConsent(String textVersion) async {
    await _json('POST', '/v1/consent', data: {'text_version': textVersion});
  }

  @override
  Future<Profile> profile() async =>
      Profile.fromJson(await _json('GET', '/v1/profile'));

  @override
  Future<ProfileSaved> saveProfile(ProfileInput input) async =>
      ProfileSaved.fromJson(
        await _json('PUT', '/v1/profile', data: input.toJson()),
      );

  @override
  Future<DailyTarget> target() async =>
      DailyTarget.fromJson(await _json('GET', '/v1/target'));

  @override
  Future<DailyTarget> saveTarget(TargetValues values) async =>
      DailyTarget.fromJson(
        await _json('PUT', '/v1/target', data: values.toJson()),
      );

  @override
  Future<DailyTarget> recalculateTarget() async =>
      DailyTarget.fromJson(await _json('POST', '/v1/target/recalculate'));

  @override
  Future<void> deactivate() async {
    await _json('POST', '/v1/me/deactivation');
  }

  @override
  Future<List<FoodSummary>> searchFoods(String query) async =>
      _foodList(await _json('GET', '/v1/foods/search', query: {'q': query}));

  @override
  Future<Food> food(String id) async =>
      Food.fromJson(await _json('GET', '/v1/foods/$id'));

  @override
  Future<BarcodeLookup> lookupBarcode(String code) async =>
      BarcodeLookup.fromJson(
        await _json('GET', '/v1/foods/barcode', query: {'code': code}),
      );

  @override
  Future<List<FoodSummary>> customFoods() async =>
      _foodList(await _json('GET', '/v1/foods/custom'));

  @override
  Future<CustomFoodSaved> createCustomFood(CustomFoodInput input) async =>
      CustomFoodSaved.fromJson(
        await _json('POST', '/v1/foods/custom', data: input.toJson()),
      );

  @override
  Future<CustomFoodSaved> updateCustomFood(
    String id,
    CustomFoodInput input,
  ) async => CustomFoodSaved.fromJson(
    await _json('PUT', '/v1/foods/custom/$id', data: input.toJson()),
  );

  @override
  Future<void> deleteCustomFood(String id) async {
    await _json('DELETE', '/v1/foods/custom/$id');
  }

  @override
  Future<DiaryDay> diaryDay(DateTime date, int utcOffsetMin) async =>
      DiaryDay.fromJson(
        await _json(
          'GET',
          '/v1/diary/days/${isoDate(date)}',
          query: {'utc_offset_min': utcOffsetMin},
        ),
      );

  @override
  Future<AddedEntry> addEntry({
    required DateTime date,
    required Meal meal,
    required String foodId,
    double? quantity,
    double? servings,
    required int utcOffsetMin,
  }) async {
    final response = await _request(
      'POST',
      '/v1/diary/entries',
      query: {'utc_offset_min': utcOffsetMin},
      data: {
        'date': isoDate(date),
        'meal': meal.wire,
        'food_id': foodId,
        'quantity': ?quantity,
        'servings': ?servings,
      },
    );
    final location = response.headers.value('location') ?? '';
    return AddedEntry(
      day: DiaryDay.fromJson(response.data ?? const {}),
      entryId: location.split('/').last,
    );
  }

  @override
  Future<DiaryDay> updateEntry(
    String id, {
    Meal? meal,
    double? quantity,
    double? servings,
    required int utcOffsetMin,
  }) async => DiaryDay.fromJson(
    await _json(
      'PATCH',
      '/v1/diary/entries/$id',
      query: {'utc_offset_min': utcOffsetMin},
      data: {'meal': ?meal?.wire, 'quantity': ?quantity, 'servings': ?servings},
    ),
  );

  @override
  Future<DiaryDay> deleteEntry(String id, int utcOffsetMin) async =>
      DiaryDay.fromJson(
        await _json(
          'DELETE',
          '/v1/diary/entries/$id',
          query: {'utc_offset_min': utcOffsetMin},
        ),
      );

  @override
  Future<DiaryDay> restoreEntry(String id, int utcOffsetMin) async =>
      DiaryDay.fromJson(
        await _json(
          'POST',
          '/v1/diary/entries/$id/restore',
          query: {'utc_offset_min': utcOffsetMin},
        ),
      );

  @override
  Future<List<QuickFood>> recentFoods() async =>
      _quickList(await _json('GET', '/v1/foods/recent'));

  @override
  Future<List<QuickFood>> favoriteFoods() async =>
      _quickList(await _json('GET', '/v1/foods/favorites'));

  @override
  Future<void> addFavorite(String foodId) async {
    await _json('PUT', '/v1/foods/favorites/$foodId');
  }

  @override
  Future<void> removeFavorite(String foodId) async {
    await _json('DELETE', '/v1/foods/favorites/$foodId');
  }

  @override
  Future<List<CopySourceDay>> copySources(
    DateTime targetDate,
    Meal targetMeal,
  ) async {
    final json = await _json(
      'GET',
      '/v1/diary/copy-sources',
      query: {
        'target_date': isoDate(targetDate),
        'target_meal': targetMeal.wire,
      },
    );
    return (json['days'] as List<dynamic>)
        .map((e) => CopySourceDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<DiaryCopyResult> copyMeal({
    required DateTime sourceDate,
    required Meal sourceMeal,
    required DateTime targetDate,
    required Meal targetMeal,
    required int utcOffsetMin,
  }) async => DiaryCopyResult.fromJson(
    await _json(
      'POST',
      '/v1/diary/copies',
      query: {'utc_offset_min': utcOffsetMin},
      data: {
        'source_date': isoDate(sourceDate),
        'source_meal': sourceMeal.wire,
        'target_date': isoDate(targetDate),
        'target_meal': targetMeal.wire,
      },
    ),
  );

  @override
  Future<DiaryDay> undoCopy(String copyId, int utcOffsetMin) async =>
      DiaryDay.fromJson(
        await _json(
          'DELETE',
          '/v1/diary/copies/$copyId',
          query: {'utc_offset_min': utcOffsetMin},
        ),
      );

  @override
  Future<AiKeyStatus?> aiKey() async {
    try {
      return AiKeyStatus.fromJson(await _json('GET', '/v1/ai-key'));
    } on ApiError catch (e) {
      if (e.code == 'AI_KEY_NOT_FOUND') return null;
      rethrow;
    }
  }

  @override
  Future<AiKeyStatus> saveAiKey(String rawKey) async => AiKeyStatus.fromJson(
    await _json('PUT', '/v1/ai-key', data: {'raw_key': rawKey}),
  );

  @override
  Future<void> deleteAiKey() async {
    await _json('DELETE', '/v1/ai-key');
  }

  /// El análisis puede tardar hasta 55 s en el servidor: se espera algo más que el resto.
  static const analysisTimeout = Duration(seconds: 65);

  @override
  Future<PhotoAnalysisResult> analyzePhoto({
    required String photoPath,
    required Meal meal,
    required DateTime date,
    String? description,
    int? totalGrams,
  }) async {
    final bytes = await File(photoPath).readAsBytes();
    final response = await _request(
      'POST',
      '/v1/photo-analysis',
      timeout: analysisTimeout,
      // Un FormData solo se envía una vez: ante un 401 se construye otro.
      dataFactory: () => FormData.fromMap({
        'photo': MultipartFile.fromBytes(bytes, filename: 'photo.jpg'),
        'meal': meal.wire,
        'entry_date': isoDate(date),
        if (description != null && description.isNotEmpty)
          'description': description,
        'total_grams': ?totalGrams,
      }),
    );
    return PhotoAnalysisResult.fromJson(response.data ?? const {});
  }

  List<QuickFood> _quickList(Map<String, dynamic> json) =>
      (json['items'] as List<dynamic>)
          .map((e) => QuickFood.fromJson(e as Map<String, dynamic>))
          .toList();

  List<FoodSummary> _foodList(Map<String, dynamic> json) =>
      (json['items'] as List<dynamic>)
          .map((e) => FoodSummary.fromJson(e as Map<String, dynamic>))
          .toList();

  @override
  Future<List<WeightEntry>> weightEntries() async =>
      ((await _json('GET', '/v1/weight'))['entries'] as List<dynamic>)
          .map((e) => WeightEntry.fromJson(e as Map<String, dynamic>))
          .toList();

  @override
  Future<WeightEntry> saveWeight(
    DateTime day,
    double kg,
    int utcOffsetMin,
  ) async => WeightEntry.fromJson(
    await _json(
      'POST',
      '/v1/weight',
      query: {'utc_offset_min': utcOffsetMin},
      data: {'measured_on': isoDate(day), 'weight_kg': kg},
    ),
  );

  @override
  Future<WeightEntry> updateWeight(
    DateTime day,
    double kg,
    int utcOffsetMin,
  ) async => WeightEntry.fromJson(
    await _json(
      'PUT',
      '/v1/weight/${isoDate(day)}',
      query: {'utc_offset_min': utcOffsetMin},
      data: {'weight_kg': kg},
    ),
  );

  @override
  Future<void> deleteWeight(DateTime day, int utcOffsetMin) async {
    await _json(
      'DELETE',
      '/v1/weight/${isoDate(day)}',
      query: {'utc_offset_min': utcOffsetMin},
    );
  }

  @override
  Future<WeightChart> weightChart(String period, int utcOffsetMin) async =>
      WeightChart.fromJson(
        await _json(
          'GET',
          '/v1/weight/chart',
          query: {'period': period, 'utc_offset_min': utcOffsetMin},
        ),
      );

  @override
  Future<RecalcProposal> recalcProposal(int utcOffsetMin) async =>
      RecalcProposal.fromJson(
        await _json(
          'GET',
          '/v1/recalc-proposal',
          query: {'utc_offset_min': utcOffsetMin},
        ),
      );

  @override
  Future<DailyTarget> acceptRecalc(int utcOffsetMin) async =>
      DailyTarget.fromJson(
        await _json(
          'POST',
          '/v1/recalc-proposal/accept',
          query: {'utc_offset_min': utcOffsetMin},
        ),
      );

  @override
  Future<void> ignoreRecalc(int utcOffsetMin) async {
    await _json(
      'POST',
      '/v1/recalc-proposal/ignore',
      query: {'utc_offset_min': utcOffsetMin},
    );
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async =>
      (await _request(method, path, data: data, query: query)).data ?? const {};

  /// Como [_json] pero devuelve la respuesta entera, para leer cabeceras (`Location`).
  Future<Response<Map<String, dynamic>>> _request(
    String method,
    String path, {
    Object? data,
    Object? Function()? dataFactory,
    Duration? timeout,
    Map<String, dynamic>? query,
  }) async {
    var token = await accessToken();
    if (token == null) throw const SessionExpired();
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await dio.request<Map<String, dynamic>>(
          path,
          data: dataFactory != null ? dataFactory() : data,
          queryParameters: query,
          options: Options(
            method: method,
            headers: {'Authorization': 'Bearer $token'},
            sendTimeout: timeout,
            receiveTimeout: timeout,
          ),
        );
        return response;
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          if (attempt == 1) throw const SessionExpired();
          token = await refreshToken();
          if (token == null) throw const SessionExpired();
          continue;
        }
        throw mapDioError(e);
      }
    }
    throw const SessionExpired();
  }
}

/// Traduce un error de dio a un [ApiFailure] (FR-015).
ApiFailure mapDioError(DioException e) {
  final response = e.response;
  if (response == null) return const NetworkFailure();
  final status = response.statusCode ?? 0;
  final body = response.data;
  final code = body is Map<String, dynamic> ? body['code'] as String? : null;
  // Los fallos de la IA (503, 504) llevan su código: la app decide qué ofrecer (006 R11).
  final isAi = code != null && code.startsWith('AI_');
  if (!isAi && (status >= 500 || code == 'AUTH_UNAVAILABLE')) {
    return const ServerFailure();
  }
  if (code == null) return const ServerFailure();
  final header = int.tryParse(response.headers.value('retry-after') ?? '');
  final fromBody = body is Map<String, dynamic>
      ? body['retry_after_s'] as int?
      : null;
  final fields = body is Map<String, dynamic> && body['fields'] is List
      ? (body['fields'] as List<dynamic>).whereType<String>().toList()
      : const <String>[];
  return ApiError(
    code,
    status,
    retryAfterSeconds: header ?? fromBody,
    fields: fields,
  );
}

final mykcalApiProvider = Provider<MykcalApi>((ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  final auth = ref.read(authControllerProvider.notifier);
  return HttpMykcalApi(
    dio: HttpMykcalApi.buildDio(baseUrl),
    accessToken: auth.validAccessToken,
    refreshToken: auth.forceRefresh,
  );
});
