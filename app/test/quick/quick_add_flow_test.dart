import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/diary/diary_screen.dart';
import 'package:mykcal/features/foods/food_search_controller.dart';
import 'package:mykcal/features/foods/food_search_screen.dart';

import '../diary/summary_card_test.dart' show target2000;
import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

Future<Harness> pumpAdd(
  WidgetTester tester, {
  List<QuickFood> recent = const [],
  List<QuickFood> favorites = const [],
}) async {
  await tallScreen(tester);
  final h = Harness();
  h.api.onDiaryDay = (date, _) async => sampleDay(target: target2000);
  h.api.onRecentFoods = () async => recent;
  h.api.onFavoriteFoods = () async => favorites;
  h.api.onSearchFoods = (_) async => [sampleSummary(name: 'Pan integral')];
  h.api.onFood = (_) async => sampleFood(name: 'Pan de molde');
  await h.pumpScreen(tester, const Scaffold(body: DiaryScreen()));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Añadir a Cena'));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets(
    'con el campo vacío: pestañas y, sin registros, el vacío de Recientes',
    (tester) async {
      await pumpAdd(tester);
      expect(find.byType(FoodSearchScreen), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Recientes'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Favoritos'), findsOneWidget);
      expect(
        find.text(
          'Aquí aparecerán los alimentos que registres, para añadirlos con un toque.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Favoritos vacío explica cómo marcar', (tester) async {
    await pumpAdd(tester);
    await tester.tap(find.widgetWithText(Tab, 'Favoritos'));
    await tester.pumpAndSettle();
    expect(
      find.text('Marca alimentos con ☆ para tenerlos a mano aquí.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'al escribir se ocultan las pestañas y al borrar vuelven en la misma',
    (tester) async {
      await pumpAdd(
        tester,
        favorites: [sampleQuick(name: 'Yogur', favorite: true)],
      );
      await tester.tap(find.widgetWithText(Tab, 'Favoritos'));
      await tester.pumpAndSettle();
      expect(find.text('Yogur'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'pan');
      await tester.pump(searchDebounce + const Duration(milliseconds: 10));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Pan integral'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Yogur'), findsOneWidget); // sigue en Favoritos
    },
  );

  testWidgets('error de red en Recientes: «Reintentar» vuelve a pedir', (
    tester,
  ) async {
    await tallScreen(tester);
    final h = Harness();
    h.api.onDiaryDay = (_, _) async => sampleDay(target: target2000);
    var fail = true;
    h.api.onRecentFoods = () async {
      if (fail) throw const NetworkFailure();
      return [sampleQuick(name: 'Pan de molde')];
    };
    await h.pumpScreen(tester, const Scaffold(body: DiaryScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Añadir a Cena'));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Pan de molde'), findsOneWidget);
  });

  testWidgets(
    '«+» añade con la cantidad sugerida, sigue abierta y ofrece deshacer 5 s',
    (tester) async {
      final h = await pumpAdd(
        tester,
        recent: [sampleQuick(name: 'Pan de molde', quantity: 60, servings: 2)],
      );
      h.api.addedEntryId = 'new-1';
      h.api.onAddEntry = (call) async => sampleDay(
        target: target2000,
        entries: [sampleEntry(name: 'Pan de molde', meal: Meal.dinner)],
      );
      await tester.tap(find.byTooltip('Añadir Pan de molde, 2 raciones, 60 g'));
      await tester.pumpAndSettle();
      final call = h.api.addedEntries.single;
      expect(call.meal, Meal.dinner);
      expect(call.foodId, 'food-1');
      expect(call.servings, 2); // raciones, no gramos
      expect(call.quantity, isNull);
      expect(find.byType(FoodSearchScreen), findsOneWidget); // sigue abierta
      expect(find.text('Pan de molde añadido a Cena'), findsOneWidget);
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.duration, const Duration(seconds: 5));
    },
  );

  testWidgets('sin ración sugerida envía quantity', (tester) async {
    final h = await pumpAdd(tester, recent: [sampleQuick(quantity: 90)]);
    await tester.tap(find.byTooltip('Añadir Pan de molde, 90 g'));
    await tester.pumpAndSettle();
    expect(h.api.addedEntries.single.quantity, 90);
    expect(h.api.addedEntries.single.servings, isNull);
  });

  testWidgets('«Deshacer» borra la entrada creada y avisa', (tester) async {
    final h = await pumpAdd(tester, recent: [sampleQuick()]);
    h.api.addedEntryId = 'new-1';
    await tester.tap(find.byTooltip('Añadir Pan de molde, 60 g'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(h.api.deletedEntries, ['new-1']);
    expect(find.text('Deshecho'), findsOneWidget);
  });

  testWidgets('si deshacer falla pide borrarla desde el diario', (
    tester,
  ) async {
    final h = await pumpAdd(tester, recent: [sampleQuick()]);
    h.api.onDeleteEntry = (_, _) async => throw const NetworkFailure();
    await tester.tap(find.byTooltip('Añadir Pan de molde, 60 g'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudo deshacer. Borra la entrada desde el diario.'),
      findsOneWidget,
    );
  });

  testWidgets('sin conexión al añadir: aviso con «Reintentar»', (tester) async {
    final h = await pumpAdd(tester, recent: [sampleQuick()]);
    h.api.onAddEntry = (_) async => throw const NetworkFailure();
    await tester.tap(find.byTooltip('Añadir Pan de molde, 60 g'));
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión. Inténtalo de nuevo.'), findsOneWidget);
    h.api.onAddEntry = (c) async => sampleDay(target: target2000);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(h.api.addedEntries, hasLength(2));
  });

  testWidgets('tocar el alimento abre la hoja con la cantidad sugerida', (
    tester,
  ) async {
    final h = await pumpAdd(
      tester,
      recent: [sampleQuick(quantity: 90, name: 'Pan de molde')],
    );
    await tester.tap(find.text('Pan de molde'));
    await tester.pumpAndSettle();
    expect(find.text('Cantidad'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Cantidad'),
    );
    expect(field.controller!.text, '90');
    await tester.enterText(find.widgetWithText(TextField, 'Cantidad'), '120');
    await tester.pump();
    h.api.onAddEntry = (c) async => sampleDay(target: target2000);
    await tester.tap(find.widgetWithText(FilledButton, 'Añadir'));
    await tester.pumpAndSettle();
    expect(h.api.addedEntries.single.quantity, 120);
    expect(find.byType(FoodSearchScreen), findsNothing); // vuelve al diario
    expect(find.text('Añadido a Cena'), findsOneWidget);
  });

  testWidgets('la hoja con raciones sugeridas empieza en raciones', (
    tester,
  ) async {
    await pumpAdd(
      tester,
      recent: [sampleQuick(quantity: 60, servings: 2, name: 'Galletas')],
    );
    await tester.tap(find.text('Galletas'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Cantidad'),
    );
    expect(field.controller!.text, '2');
  });

  testWidgets(
    'quitar un favorito desde su pestaña lo oculta y ofrece deshacer',
    (tester) async {
      final h = await pumpAdd(
        tester,
        favorites: [sampleQuick(name: 'Yogur', favorite: true)],
      );
      await tester.tap(find.widgetWithText(Tab, 'Favoritos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quitar Yogur de favoritos'));
      await tester.pumpAndSettle();
      expect(find.text('Yogur'), findsNothing);
      expect(find.text('Quitado de favoritos'), findsOneWidget);
      expect(h.api.favoriteRemoves, ['food-1']);
      h.api.onFavoriteFoods = () async => [
        sampleQuick(name: 'Yogur', favorite: true),
      ];
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(h.api.favoriteAdds, ['food-1']);
      expect(find.text('Yogur'), findsOneWidget);
    },
  );

  testWidgets('la fila de favoritos nunca usados usa la ración sugerida', (
    tester,
  ) async {
    final h = await pumpAdd(
      tester,
      favorites: [
        QuickFood(
          food: sampleFood(name: 'Galletas', servingSize: 30),
          suggestedQuantity: 30,
          suggestedServings: 1,
          isFavorite: true,
        ),
      ],
    );
    await tester.tap(find.widgetWithText(Tab, 'Favoritos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Añadir Galletas, 1 ración, 30 g'));
    await tester.pumpAndSettle();
    expect(h.api.addedEntries.single.servings, 1);
  });

  testWidgets('accesible: etiquetas, zonas táctiles y contraste', (
    tester,
  ) async {
    await pumpAdd(
      tester,
      recent: [
        sampleQuick(
          name: 'Pan de molde',
          brand: 'Bimbo',
          quantity: 60,
          servings: 2,
        ),
      ],
    );
    expect(
      find.byTooltip('Añadir Pan de molde, 2 raciones, 60 g'),
      findsOneWidget,
    );
    expect(find.byTooltip('Marcar Pan de molde como favorito'), findsOneWidget);
    final plus = tester.getSize(
      find.byTooltip('Añadir Pan de molde, 2 raciones, 60 g'),
    );
    expect(plus.width, greaterThanOrEqualTo(48));
    expect(plus.height, greaterThanOrEqualTo(48));
    await expectAccessible(tester);
  });

  testWidgets('texto al 200 % sin desbordes', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpAdd(
      tester,
      recent: [
        sampleQuick(
          name: 'Pan de molde integral con semillas',
          brand: 'Marca',
          servings: 2,
        ),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Pan de molde integral con semillas'), findsOneWidget);
  });
}
