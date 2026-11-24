import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
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

  List<FoodSummary> _foodList(Map<String, dynamic> json) =>
      (json['items'] as List<dynamic>)
          .map((e) => FoodSummary.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    var token = await accessToken();
    if (token == null) throw const SessionExpired();
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await dio.request<Map<String, dynamic>>(
          path,
          data: data,
          queryParameters: query,
          options: Options(
            method: method,
            headers: {'Authorization': 'Bearer $token'},
          ),
        );
        return response.data ?? const {};
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
  if (status >= 500 || code == 'AUTH_UNAVAILABLE') return const ServerFailure();
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
