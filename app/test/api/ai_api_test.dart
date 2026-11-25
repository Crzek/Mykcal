import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/core/api/mykcal_api.dart';

import 'api_client_test.dart' show StubAdapter, api, json;

Map<String, dynamic> keyJson() => {
  'has_key': true,
  'provider': 'gemini',
  'configured_at': '2026-11-25T10:00:00Z',
};

void main() {
  test(
    'aiKey: 200 devuelve el estado y 404 AI_KEY_NOT_FOUND es «sin clave»',
    () async {
      final ok = StubAdapter((_) => json(200, keyJson()));
      final status = (await api(ok).aiKey())!;
      expect(ok.requests.single.path, '/v1/ai-key');
      expect(status.provider, 'gemini');
      expect(status.configuredAt, DateTime.utc(2026, 11, 25, 10));

      final none = StubAdapter(
        (_) => json(404, {'code': 'AI_KEY_NOT_FOUND', 'message': 'x'}),
      );
      expect(await api(none).aiKey(), isNull);
    },
  );

  test('saveAiKey envía raw_key por PUT y deleteAiKey usa DELETE', () async {
    final adapter = StubAdapter((_) => json(200, keyJson()));
    await api(adapter).saveAiKey('AIzaX');
    expect(adapter.requests.single.method, 'PUT');
    expect(adapter.requests.single.data, {'raw_key': 'AIzaX'});
    final del = StubAdapter((_) => json(204, const {}));
    await api(del).deleteAiKey();
    expect(del.requests.single.method, 'DELETE');
  });

  test('saveAiKey con AI_KEY_INVALID es un ApiError con su código', () async {
    final adapter = StubAdapter(
      (_) => json(422, {'code': 'AI_KEY_INVALID', 'message': 'x'}),
    );
    await expectLater(
      api(adapter).saveAiKey('mala'),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'AI_KEY_INVALID')),
    );
  });

  group('analyzePhoto', () {
    late File photo;
    setUp(() {
      photo = File('${Directory.systemTemp.path}/mykcal-api-test.jpg')
        ..writeAsBytesSync([0xff, 0xd8, 1, 2, 3]);
    });
    tearDown(() => photo.deleteSync());

    test(
      'multipart con foto, comida, día, descripción y gramos; plazo largo',
      () async {
        final adapter = StubAdapter(
          (_) => json(200, {
            'items': [
              {
                'ai_name': 'Arroz',
                'ai_grams': 150,
                'flagged': false,
                'matched_food': {
                  'id': 'f1',
                  'kind': 'generic',
                  'name': 'Arroz, blanco',
                  'brand': null,
                  'base_unit': 'g',
                  'kcal': 130,
                  'is_mine': false,
                },
                'matched_similarity': 0.9,
                'kcal': 195,
                'protein_g': 4,
                'carbs_g': 42,
                'fat_g': 0.5,
              },
            ],
          }),
        );
        final result = await api(adapter).analyzePhoto(
          photoPath: photo.path,
          meal: Meal.lunch,
          date: DateTime(2026, 11, 25),
          description: 'arroz',
          totalGrams: 300,
        );
        final request = adapter.requests.single;
        expect(request.path, '/v1/photo-analysis');
        expect(request.method, 'POST');
        expect(request.receiveTimeout, HttpMykcalApi.analysisTimeout);
        final form = request.data as FormData;
        final fields = {for (final f in form.fields) f.key: f.value};
        expect(fields, {
          'meal': 'lunch',
          'entry_date': '2026-11-25',
          'description': 'arroz',
          'total_grams': '300',
        });
        expect(form.files.single.key, 'photo');
        expect(result.items.single.matchedFood!.name, 'Arroz, blanco');
        expect(result.items.single.kcal, 195);
      },
    );

    test('sin descripción ni gramos no los envía', () async {
      final adapter = StubAdapter((_) => json(200, {'items': []}));
      await api(adapter).analyzePhoto(
        photoPath: photo.path,
        meal: Meal.dinner,
        date: DateTime(2026, 11, 25),
      );
      final names = (adapter.requests.single.data as FormData).fields.map(
        (f) => f.key,
      );
      expect(names, isNot(contains('description')));
      expect(names, isNot(contains('total_grams')));
    });

    for (final (status, code) in [
      (403, 'AI_KEY_REQUIRED'),
      (413, 'VALIDATION_ERROR'),
      (422, 'AI_KEY_INVALID'),
      (422, 'AI_RESPONSE_INVALID'),
      (422, 'AI_UNRECOGNIZED'),
      (429, 'AI_QUOTA_EXCEEDED'),
      (503, 'AI_PROVIDER_UNAVAILABLE'),
      (504, 'AI_TIMEOUT'),
    ]) {
      test('$status $code llega como ApiError con su código', () async {
        final adapter = StubAdapter(
          (_) => json(status, {'code': code, 'message': 'x'}),
        );
        await expectLater(
          api(adapter).analyzePhoto(
            photoPath: photo.path,
            meal: Meal.lunch,
            date: DateTime(2026, 11, 25),
          ),
          throwsA(isA<ApiError>().having((e) => e.code, 'code', code)),
        );
      });
    }

    test(
      'ante un 401 renueva y reenvía la foto con un FormData nuevo',
      () async {
        var calls = 0;
        final adapter = StubAdapter(
          (_) => ++calls == 1
              ? json(401, {'code': 'UNAUTHORIZED', 'message': 'x'})
              : json(200, {'items': []}),
        );
        await api(adapter).analyzePhoto(
          photoPath: photo.path,
          meal: Meal.lunch,
          date: DateTime(2026, 11, 25),
        );
        expect(adapter.requests, hasLength(2));
        expect(adapter.requests.last.headers['Authorization'], 'Bearer tok-2');
      },
    );
  });
}
