import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/features/quick/favorite_star.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

Future<Harness> pumpStar(
  WidgetTester tester, {
  bool favorite = false,
  ValueChanged<bool>? onChanged,
}) async {
  final h = Harness();
  h.api.onFavoriteFoods = () async => [
    if (favorite) sampleQuick(id: 'f1', name: 'Pan', favorite: true),
  ];
  await h.pumpScreen(
    tester,
    Scaffold(
      body: FavoriteStar(foodId: 'f1', foodName: 'Pan', onChanged: onChanged),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('etiqueta «Marcar … como favorito» y no empieza por «Añadir»', (
    tester,
  ) async {
    await pumpStar(tester);
    final tooltip = find.byTooltip('Marcar Pan como favorito');
    expect(tooltip, findsOneWidget);
    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(find.byTooltip(RegExp('^Añadir')), findsNothing);
    await expectAccessible(tester);
  });

  testWidgets('con el alimento marcado dice «Quitar … de favoritos»', (
    tester,
  ) async {
    await pumpStar(tester, favorite: true);
    expect(find.byTooltip('Quitar Pan de favoritos'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('tocar marca, cambia la etiqueta y avisa con true', (
    tester,
  ) async {
    final changes = <bool>[];
    final h = await pumpStar(tester, onChanged: changes.add);
    h.api.onAddFavorite = (_) async {
      h.api.onFavoriteFoods = () async => [
        sampleQuick(id: 'f1', name: 'Pan', favorite: true),
      ];
    };
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(h.api.favoriteAdds, ['f1']);
    expect(changes, [true]);
    expect(find.byTooltip('Quitar Pan de favoritos'), findsOneWidget);
  });

  testWidgets('FOOD_NOT_FOUND avisa y deja la estrella como estaba', (
    tester,
  ) async {
    final h = await pumpStar(tester);
    h.api.onAddFavorite = (_) async =>
        throw const ApiError('FOOD_NOT_FOUND', 404);
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.text('Este alimento ya no está disponible'), findsOneWidget);
    expect(find.byTooltip('Marcar Pan como favorito'), findsOneWidget);
  });

  testWidgets('sin conexión avisa y no cambia', (tester) async {
    final h = await pumpStar(tester);
    h.api.onAddFavorite = (_) async => throw const NetworkFailure();
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión. Inténtalo de nuevo.'), findsOneWidget);
    expect(find.byTooltip('Marcar Pan como favorito'), findsOneWidget);
  });
}
