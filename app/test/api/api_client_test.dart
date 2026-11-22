import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/mykcal_api.dart';

/// Adaptador de dio que responde con lo que se le indique, sin red.
class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? body, Future<void>? cancel) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Map<String, dynamic> body, {Map<String, List<String>>? headers}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        ...?headers,
      },
    );

const meJson = {'id': 'x', 'display_name': 'Ana', 'is_admin': false, 'status': 'active'};

HttpMykcalApi api(StubAdapter adapter, {TokenSource? access, TokenSource? refresh}) {
  final dio = HttpMykcalApi.buildDio('https://api.test')..httpClientAdapter = adapter;
  return HttpMykcalApi(
    dio: dio,
    accessToken: access ?? () async => 'tok-1',
    refreshToken: refresh ?? () async => 'tok-2',
  );
}

void main() {
  test('añade el bearer y parsea /v1/me', () async {
    final adapter = StubAdapter((_) => json(200, meJson));
    final me = await api(adapter).me();
    expect(me.displayName, 'Ana');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer tok-1');
  });

  test('401 → renueva una vez y reintenta con el token nuevo', () async {
    var n = 0;
    final adapter = StubAdapter((o) => n++ == 0 ? json(401, {'code': 'UNAUTHORIZED', 'message': ''}) : json(200, meJson));
    final me = await api(adapter).me();
    expect(me.active, isTrue);
    expect(adapter.requests.map((r) => r.headers['Authorization']), ['Bearer tok-1', 'Bearer tok-2']);
  });

  test('401 repetido o renovación fallida → SessionExpired', () async {
    final always401 = StubAdapter((_) => json(401, {'code': 'UNAUTHORIZED', 'message': ''}));
    await expectLater(api(always401).me(), throwsA(isA<SessionExpired>()));
    final noRefresh = StubAdapter((_) => json(401, {'code': 'UNAUTHORIZED', 'message': ''}));
    await expectLater(api(noRefresh, refresh: () async => null).me(), throwsA(isA<SessionExpired>()));
    await expectLater(api(StubAdapter((_) => json(200, meJson)), access: () async => null).me(), throwsA(isA<SessionExpired>()));
  });

  test('errores de red y timeouts → NetworkFailure (FR-015)', () async {
    for (final type in [DioExceptionType.connectionError, DioExceptionType.connectionTimeout, DioExceptionType.receiveTimeout]) {
      final adapter = StubAdapter((o) => throw DioException(requestOptions: o, type: type));
      await expectLater(api(adapter).me(), throwsA(isA<NetworkFailure>()));
    }
  });

  test('5xx y AUTH_UNAVAILABLE → ServerFailure', () async {
    await expectLater(api(StubAdapter((_) => json(500, {'code': 'INTERNAL_ERROR', 'message': ''}))).me(), throwsA(isA<ServerFailure>()));
    await expectLater(api(StubAdapter((_) => json(503, {'code': 'AUTH_UNAVAILABLE', 'message': ''}))).me(), throwsA(isA<ServerFailure>()));
  });

  test('el code del cuerpo se traduce a ApiError, con Retry-After', () async {
    final adapter = StubAdapter((_) => json(429, {'code': 'TOO_MANY_ATTEMPTS', 'message': '', 'retry_after_s': 42}, headers: {'retry-after': ['42']}));
    try {
      await api(adapter).register('ABCD');
      fail('debería lanzar');
    } on ApiError catch (e) {
      expect(e.code, 'TOO_MANY_ATTEMPTS');
      expect(e.status, 429);
      expect(e.retryAfterSeconds, 42);
    }
    expect(jsonDecode(adapter.requests.single.data is String ? adapter.requests.single.data as String : jsonEncode(adapter.requests.single.data)), {'invitation_code': 'ABCD'});
  });

  test('admin: invitation y rotate', () async {
    const body = {'code': 'ABCD2345', 'created_at': null, 'active_accounts': 3, 'max_accounts': 50, 'free_seats': 47};
    final adapter = StubAdapter((_) => json(200, body));
    final a = api(adapter);
    expect((await a.invitation()).displayCode, 'ABCD-2345');
    expect((await a.rotateInvitation()).freeSeats, 47);
    expect(adapter.requests.map((r) => '${r.method} ${r.path}'), ['GET /v1/admin/invitation', 'POST /v1/admin/invitation/rotate']);
  });
}
