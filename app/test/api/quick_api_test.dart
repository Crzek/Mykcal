import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';

import 'api_client_test.dart' show StubAdapter, api, json;
import 'diary_api_test.dart' show dayJson;
import 'foods_api_test.dart' show foodJson;

Map<String, dynamic> quickJson({double? servings, bool favorite = false}) => {
  'food': foodJson(),
  'suggested_quantity': 60,
  'suggested_servings': servings,
  'last_used_at': '2026-11-24T07:42:10Z',
  'is_favorite': favorite,
};

void main() {
  test('recentFoods y favoriteFoods leen QuickFood', () async {
    final adapter = StubAdapter(
      (_) => json(200, {
        'items': [quickJson(servings: 2, favorite: true)],
      }),
    );
    final client = api(adapter);
    final recent = await client.recentFoods();
    final favorites = await client.favoriteFoods();
    expect(adapter.requests[0].path, '/v1/foods/recent');
    expect(adapter.requests[1].path, '/v1/foods/favorites');
    expect(recent.single.suggestedQuantity, 60);
    expect(recent.single.suggestedServings, 2);
    expect(recent.single.isFavorite, isTrue);
    expect(favorites.single.food.name, 'Plátano, crudo');
    expect(recent.single.lastUsedAt, isNotNull);
  });

  test('suggestedServings y lastUsedAt pueden ser null', () async {
    final adapter = StubAdapter(
      (_) => json(200, {
        'items': [
          {...quickJson(), 'last_used_at': null},
        ],
      }),
    );
    final item = (await api(adapter).recentFoods()).single;
    expect(item.suggestedServings, isNull);
    expect(item.lastUsedAt, isNull);
  });

  test('addFavorite y removeFavorite usan PUT y DELETE', () async {
    final adapter = StubAdapter((_) => json(204, const {}));
    final client = api(adapter);
    await client.addFavorite('f1');
    await client.removeFavorite('f1');
    expect(adapter.requests[0].method, 'PUT');
    expect(adapter.requests[0].path, '/v1/foods/favorites/f1');
    expect(adapter.requests[1].method, 'DELETE');
  });

  test('addEntry lee el id de la cabecera Location', () async {
    final adapter = StubAdapter(
      (_) => json(
        201,
        dayJson(),
        headers: {
          'location': ['/v1/diary/entries/abc-123'],
        },
      ),
    );
    final added = await api(adapter).addEntry(
      date: DateTime(2026, 11, 24),
      meal: Meal.dinner,
      foodId: 'f1',
      quantity: 60,
      utcOffsetMin: 60,
    );
    expect(added.entryId, 'abc-123');
    expect(added.day.date, DateTime(2026, 11, 24));
  });

  test('copySources manda la fecha y la comida destino', () async {
    final adapter = StubAdapter(
      (_) => json(200, {
        'days': [
          {
            'date': '2026-11-23',
            'meals': [
              {
                'meal': 'dinner',
                'kcal': 620,
                'values_changed': true,
                'entries': [
                  {
                    'food_name': 'Merluza',
                    'food_brand': null,
                    'base_unit': 'g',
                    'quantity': 150,
                    'servings': null,
                    'kcal': 180,
                  },
                ],
              },
            ],
          },
        ],
      }),
    );
    final days = await api(adapter)
        .copySources(DateTime(2026, 11, 24), Meal.dinner);
    final req = adapter.requests.single;
    expect(req.path, '/v1/diary/copy-sources');
    expect(req.queryParameters, {
      'target_date': '2026-11-24',
      'target_meal': 'dinner',
    });
    expect(days.single.date, DateTime(2026, 11, 23));
    expect(days.single.meals.single.valuesChanged, isTrue);
    expect(days.single.meals.single.entries.single.foodName, 'Merluza');
  });

  test('copyMeal y undoCopy usan sus rutas', () async {
    final adapter = StubAdapter(
      (o) => o.method == 'POST'
          ? json(201, {
              'copy_id': 'c1',
              'entry_ids': ['e1', 'e2'],
              'day': dayJson(),
            })
          : json(200, dayJson()),
    );
    final client = api(adapter);
    final result = await client.copyMeal(
      sourceDate: DateTime(2026, 11, 23),
      sourceMeal: Meal.breakfast,
      targetDate: DateTime(2026, 11, 24),
      targetMeal: Meal.dinner,
      utcOffsetMin: 60,
    );
    await client.undoCopy('c1', 60);
    expect(adapter.requests[0].path, '/v1/diary/copies');
    expect(adapter.requests[0].queryParameters, {'utc_offset_min': 60});
    expect(adapter.requests[0].data, {
      'source_date': '2026-11-23',
      'source_meal': 'breakfast',
      'target_date': '2026-11-24',
      'target_meal': 'dinner',
    });
    expect(result.copyId, 'c1');
    expect(result.entryIds, ['e1', 'e2']);
    expect(adapter.requests[1].method, 'DELETE');
    expect(adapter.requests[1].path, '/v1/diary/copies/c1');
  });

  test('mapea los errores de la copia y los favoritos', () async {
    Future<ApiError> fail(int status, String code) async {
      final adapter = StubAdapter(
        (_) => json(status, {'code': code, 'message': 'x'}),
      );
      try {
        await api(adapter).undoCopy('c1', 0);
      } on ApiError catch (e) {
        return e;
      }
      throw StateError('no falló');
    }

    expect((await fail(404, 'COPY_NOT_FOUND')).code, 'COPY_NOT_FOUND');
    expect((await fail(400, 'COPY_SOURCE_EMPTY')).code, 'COPY_SOURCE_EMPTY');
    expect((await fail(404, 'FOOD_NOT_FOUND')).status, 404);
  });
}
