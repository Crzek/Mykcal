import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/features/quick/favorites_controller.dart';

import '../helpers/fakes.dart';

void main() {
  Future<(Harness, dynamic)> setup({List<dynamic>? items}) async {
    final h = Harness();
    h.api.onFavoriteFoods = () async => [
      sampleQuick(id: 'f1', name: 'Plátano', favorite: true),
    ];
    final c = h.container();
    c.listen(favoritesControllerProvider, (_, _) {});
    await c.read(favoritesControllerProvider.future);
    return (h, c);
  }

  test('favoriteIdsProvider refleja el conjunto cargado', () async {
    final (_, c) = await setup();
    expect(c.read(favoriteIdsProvider), {'f1'});
  });

  test('toggle marca de forma optimista y recarga la lista', () async {
    final (h, c) = await setup();
    var favorites = ['f1'];
    h.api.onAddFavorite = (id) async => favorites.add(id);
    h.api.onFavoriteFoods = () async => [
      for (final id in favorites) sampleQuick(id: id, name: id, favorite: true),
    ];
    final pending = c.read(favoritesControllerProvider.notifier).toggle('f2');
    expect(c.read(favoriteIdsProvider), {'f1', 'f2'}); // al momento
    await pending;
    expect(h.api.favoriteAdds, ['f2']);
    expect(
      c.read(favoritesControllerProvider).value!.items.map((i) => i.food.id),
      ['f1', 'f2'],
    );
  });

  test('toggle de un favorito lo quita de la lista al momento', () async {
    final (h, c) = await setup();
    final pending = c.read(favoritesControllerProvider.notifier).toggle('f1');
    expect(c.read(favoriteIdsProvider), isEmpty);
    expect(c.read(favoritesControllerProvider).value!.items, isEmpty);
    await pending;
    expect(h.api.favoriteRemoves, ['f1']);
  });

  test('si la petición falla se revierte y se relanza el error', () async {
    final (h, c) = await setup();
    h.api.onAddFavorite = (_) async => throw const NetworkFailure();
    await expectLater(
      c.read(favoritesControllerProvider.notifier).toggle('f2'),
      throwsA(isA<NetworkFailure>()),
    );
    expect(c.read(favoriteIdsProvider), {'f1'});
  });

  test('FOOD_NOT_FOUND al marcar deja la estrella como estaba', () async {
    final (h, c) = await setup();
    h.api.onAddFavorite = (_) async =>
        throw const ApiError('FOOD_NOT_FOUND', 404);
    await expectLater(
      c.read(favoritesControllerProvider.notifier).toggle('gone'),
      throwsA(isA<ApiError>()),
    );
    expect(c.read(favoriteIdsProvider), {'f1'});
  });
}
