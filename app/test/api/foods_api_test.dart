import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';

import 'api_client_test.dart' show StubAdapter, api, json;

const nutrientsJson = {
  'kcal': 90,
  'protein_g': 1.1,
  'carbs_g': 19.7,
  'fat_g': 0.3,
  'fiber_g': 2,
  'sodium_mg': null,
  'potassium_mg': 358.5,
  'calcium_mg': null,
  'iron_mg': null,
  'magnesium_mg': null,
  'vitamin_d_ug': null,
  'vitamin_c_mg': 8.7,
};

Map<String, dynamic> foodJson({String kind = 'generic'}) => {
  'id': 'f1',
  'kind': kind,
  'name': 'Plátano, crudo',
  'brand': null,
  'barcode': null,
  'base_unit': 'g',
  'per_100': nutrientsJson,
  'serving_size': null,
  'is_mine': kind == 'custom',
  'source': 'ciqual',
  'updated_at': '2026-11-24T10:00:00Z',
};

void main() {
  test('searchFoods envía q como query y parsea las filas', () async {
    final adapter = StubAdapter(
      (_) => json(200, {
        'items': [
          {
            'id': 'f1',
            'kind': 'custom',
            'name': 'Tarta',
            'brand': null,
            'base_unit': 'g',
            'kcal': 320,
            'is_mine': true,
          },
        ],
      }),
    );
    final items = await api(adapter).searchFoods('platano');
    expect(adapter.requests.single.path, '/v1/foods/search');
    expect(adapter.requests.single.queryParameters, {'q': 'platano'});
    expect(items.single.kind, FoodKind.custom);
    expect(items.single.isMine, isTrue);
    expect(items.single.kcal, 320.0);
  });

  test('food conserva null como «sin dato» y distingue el 0', () async {
    final adapter = StubAdapter((_) => json(200, foodJson()));
    final food = await api(adapter).food('f1');
    expect(adapter.requests.single.path, '/v1/foods/f1');
    expect(food.per100.potassiumMg, 358.5);
    expect(food.per100.sodiumMg, isNull);
    expect(food.per100.hasMissing, isTrue);
    expect(food.servingSize, isNull);
  });

  test('lookupBarcode: found, not_found e incomplete', () async {
    final found = StubAdapter(
      (_) => json(200, {
        'result': 'found',
        'code': '8410000000009',
        'food': foodJson(kind: 'packaged'),
        'stale': true,
      }),
    );
    final r = await api(found).lookupBarcode('8410000000009');
    expect(found.requests.single.queryParameters, {'code': '8410000000009'});
    expect(r.result, BarcodeResult.found);
    expect(r.stale, isTrue);
    expect(r.food?.kind, FoodKind.packaged);

    final missing = StubAdapter(
      (_) => json(200, {'result': 'not_found', 'code': '8410000000009'}),
    );
    expect(
      (await api(missing).lookupBarcode('8410000000009')).result,
      BarcodeResult.notFound,
    );

    final incomplete = StubAdapter(
      (_) => json(200, {
        'result': 'incomplete',
        'code': '8410000000009',
        'product_name': 'Galletas',
        'brand': 'Marca',
      }),
    );
    final i = await api(incomplete).lookupBarcode('8410000000009');
    expect(i.result, BarcodeResult.incomplete);
    expect(i.productName, 'Galletas');
    expect(i.brand, 'Marca');
    expect(i.food, isNull);
  });

  test('createCustomFood envía solo los valores con dato', () async {
    final adapter = StubAdapter(
      (_) => json(201, {
        'food': foodJson(kind: 'custom'),
        'warnings': ['KCAL_MISMATCH'],
      }),
    );
    final saved = await api(adapter).createCustomFood(
      const CustomFoodInput(
        name: 'Tarta',
        baseUnit: 'g',
        basis: FoodBasis.perServing,
        servingSize: 150,
        values: Nutrients(kcal: 480, proteinG: 9, carbsG: 68, fatG: 19.5),
      ),
    );
    expect(saved.kcalMismatch, isTrue);
    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/v1/foods/custom');
    final body = req.data as Map<String, dynamic>;
    expect(body['basis'], 'per_serving');
    expect(body['serving_size'], 150);
    expect(body.containsKey('brand'), isFalse);
    expect(
      (body['values'] as Map).keys,
      containsAll(['kcal', 'protein_g', 'carbs_g', 'fat_g']),
    );
    expect((body['values'] as Map).containsKey('fiber_g'), isFalse);
  });

  test('updateCustomFood y deleteCustomFood usan la ruta del id', () async {
    final put = StubAdapter(
      (_) => json(200, {'food': foodJson(kind: 'custom'), 'warnings': []}),
    );
    await api(put).updateCustomFood(
      'f1',
      const CustomFoodInput(
        name: 'Tarta',
        baseUnit: 'g',
        basis: FoodBasis.per100,
        values: Nutrients(kcal: 1, proteinG: 1, carbsG: 1, fatG: 1),
      ),
    );
    expect(put.requests.single.method, 'PUT');
    expect(put.requests.single.path, '/v1/foods/custom/f1');

    final del = StubAdapter((_) => json(204, const {}));
    await api(del).deleteCustomFood('f1');
    expect(del.requests.single.method, 'DELETE');
    expect(del.requests.single.path, '/v1/foods/custom/f1');
  });

  test('códigos FOOD_* y VALIDATION_ERROR con fields', () async {
    Future<ApiError> fail(
      int status,
      String code, [
      List<String>? fields,
    ]) async {
      final adapter = StubAdapter(
        (_) => json(status, {'code': code, 'message': '', 'fields': ?fields}),
      );
      try {
        await api(adapter).deleteCustomFood('x');
      } on ApiError catch (e) {
        return e;
      }
      throw StateError('debería lanzar');
    }

    expect((await fail(404, 'FOOD_NOT_FOUND')).code, 'FOOD_NOT_FOUND');
    expect((await fail(409, 'FOOD_BARCODE_TAKEN')).status, 409);
    final validation = await fail(400, 'VALIDATION_ERROR', [
      'fat_g',
      'carbs_g',
    ]);
    expect(validation.fields, ['fat_g', 'carbs_g']);

    final unavailable = StubAdapter(
      (_) => json(503, {'code': 'FOOD_SOURCE_UNAVAILABLE', 'message': ''}),
    );
    await expectLater(
      api(unavailable).lookupBarcode('8410000000009'),
      throwsA(isA<ServerFailure>()),
    );
  });

  test('el cuerpo se serializa a JSON válido', () {
    expect(
      jsonEncode(
        const CustomFoodInput(
          name: 'A',
          baseUnit: 'ml',
          basis: FoodBasis.per100,
          values: Nutrients(kcal: 1, proteinG: 1, carbsG: 1, fatG: 1),
        ).toJson(),
      ),
      contains('"base_unit":"ml"'),
    );
  });
}
