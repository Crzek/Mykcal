import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';

import 'api_client_test.dart' show StubAdapter, api, json;
import 'foods_api_test.dart' show nutrientsJson;

const _targetJson = {
  'kcal': 2000,
  'protein_g': 150,
  'carbs_g': 200,
  'fat_g': 56,
  'fiber_g': 25,
  'sodium_mg': 2300,
  'potassium_mg': 3500,
  'calcium_mg': 1000,
  'iron_mg': 8,
  'magnesium_mg': 400,
  'vitamin_d_ug': 15,
  'vitamin_c_mg': 90,
};

const _amountsJson = {
  'kcal': 300,
  'protein_g': 9.5,
  'carbs_g': 12,
  'fat_g': 3,
  'fiber_g': null,
  'sodium_mg': null,
  'potassium_mg': null,
  'calcium_mg': null,
  'iron_mg': null,
  'magnesium_mg': null,
  'vitamin_d_ug': null,
  'vitamin_c_mg': null,
};

Map<String, dynamic> dayJson() => {
  'date': '2026-11-24',
  'target': _targetJson,
  'totals': {
    'consumed': _amountsJson,
    'incomplete': ['fiber_g'],
  },
  'remaining': {for (final k in _targetJson.keys) k: 10},
  'meals': [
    for (final m in [
      'breakfast',
      'lunch',
      'afternoon_snack',
      'dinner',
      'snacks',
    ])
      {
        'meal': m,
        'entries': m == 'breakfast'
            ? [
                {
                  'id': 'e1',
                  'meal': 'breakfast',
                  'food_id': 'f1',
                  'food_kind': 'generic',
                  'food_name': 'Pan',
                  'food_brand': null,
                  'base_unit': 'g',
                  'serving_size': 30,
                  'per_100': nutrientsJson,
                  'quantity': 60,
                  'servings': 2,
                  'values': _amountsJson,
                  'incomplete': ['fiber_g'],
                  'created_at': '2026-11-24T08:00:00Z',
                },
              ]
            : [],
        'totals': {'consumed': _amountsJson, 'incomplete': []},
      },
  ],
};

void main() {
  test('diaryDay envía la fecha en la ruta y utc_offset_min', () async {
    final adapter = StubAdapter((_) => json(200, dayJson()));
    final day = await api(adapter).diaryDay(DateTime(2026, 11, 24), 60);
    final req = adapter.requests.single;
    expect(req.method, 'GET');
    expect(req.path, '/v1/diary/days/2026-11-24');
    expect(req.queryParameters, {'utc_offset_min': 60});
    expect(day.date, DateTime(2026, 11, 24));
    expect(day.target.kcal, 2000);
    expect(day.meals.map((m) => m.meal), Meal.values);
    final entry = day.meal(Meal.breakfast).entries.single;
    expect(entry.servings, 2);
    expect(entry.servingSize, 30);
    expect(entry.per100.sodiumMg, isNull);
    expect(entry.values.fiberG, isNull);
    expect(entry.incomplete, ['fiber_g']);
    expect(day.totals.incomplete, ['fiber_g']);
    expect(day.remaining['kcal'], 10);
  });

  test('addEntry manda solo quantity o servings', () async {
    final adapter = StubAdapter((_) => json(201, dayJson()));
    await api(adapter).addEntry(
      date: DateTime(2026, 11, 24),
      meal: Meal.afternoonSnack,
      foodId: 'f1',
      servings: 2,
      utcOffsetMin: -300,
    );
    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/v1/diary/entries');
    expect(req.queryParameters, {'utc_offset_min': -300});
    expect(req.data, {
      'date': '2026-11-24',
      'meal': 'afternoon_snack',
      'food_id': 'f1',
      'servings': 2.0,
    });
  });

  test('updateEntry manda solo lo que cambia', () async {
    final adapter = StubAdapter((_) => json(200, dayJson()));
    await api(adapter)
        .updateEntry('e1', meal: Meal.dinner, quantity: 80, utcOffsetMin: 60);
    final req = adapter.requests.single;
    expect(req.method, 'PATCH');
    expect(req.path, '/v1/diary/entries/e1');
    expect(req.data, {'meal': 'dinner', 'quantity': 80.0});
  });

  test('deleteEntry y restoreEntry usan sus rutas', () async {
    final adapter = StubAdapter((_) => json(200, dayJson()));
    final client = api(adapter);
    await client.deleteEntry('e1', 60);
    await client.restoreEntry('e1', 60);
    expect(adapter.requests[0].method, 'DELETE');
    expect(adapter.requests[0].path, '/v1/diary/entries/e1');
    expect(adapter.requests[1].method, 'POST');
    expect(adapter.requests[1].path, '/v1/diary/entries/e1/restore');
    expect(adapter.requests[1].queryParameters, {'utc_offset_min': 60});
  });

  test('mapea los errores del diario', () async {
    Future<ApiError> fail(
      int status,
      String code, {
      List<String>? fields,
    }) async {
      final adapter = StubAdapter(
        (_) => json(status, {'code': code, 'message': 'x', 'fields': ?fields}),
      );
      try {
        await api(adapter).diaryDay(DateTime(2026, 11, 24), 0);
      } on ApiError catch (e) {
        return e;
      }
      throw StateError('no falló');
    }

    expect(
      (await fail(400, 'DIARY_DATE_OUT_OF_RANGE')).code,
      'DIARY_DATE_OUT_OF_RANGE',
    );
    expect((await fail(404, 'ENTRY_NOT_FOUND')).status, 404);
    expect((await fail(404, 'FOOD_NOT_FOUND')).code, 'FOOD_NOT_FOUND');
    final validation = await fail(
      400,
      'VALIDATION_ERROR',
      fields: ['servings'],
    );
    expect(validation.fields, ['servings']);
  });

  test('Me.fromJson lee registered_at', () {
    final me = Me.fromJson({
      'id': 'u',
      'display_name': 'Ana',
      'is_admin': false,
      'status': 'active',
      'onboarding': 'done',
      'registered_at': '2026-11-10T08:30:00Z',
    });
    expect(me.registeredAt, DateTime.utc(2026, 11, 10, 8, 30));
  });
}
