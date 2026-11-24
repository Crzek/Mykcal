import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/foods/food_search_controller.dart';
import 'package:mykcal/features/foods/food_search_screen.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Future<void> _debounce(WidgetTester tester) async {
  await tester.pump(searchDebounce + const Duration(milliseconds: 10));
  await tester.pump();
}

void main() {
  testWidgets('menos de 2 letras no llama a la API y avisa', (tester) async {
    final h = Harness();
    var calls = 0;
    h.api.onSearchFoods = (_) async {
      calls++;
      return const [];
    };
    await h.pumpScreen(tester, const FoodSearchScreen());
    await _type(tester, 'p');
    await _debounce(tester);
    expect(calls, 0);
    expect(find.text('Escribe al menos 2 letras'), findsOneWidget);
  });

  testWidgets('el debounce hace una sola llamada', (tester) async {
    final h = Harness();
    final queries = <String>[];
    h.api.onSearchFoods = (q) async {
      queries.add(q);
      return [sampleSummary()];
    };
    await h.pumpScreen(tester, const FoodSearchScreen());
    for (final t in ['pl', 'pla', 'plat', 'plata']) {
      await _type(tester, t);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _debounce(tester);
    expect(queries, ['plata']);
    expect(find.text('Plátano, crudo'), findsOneWidget);
  });

  testWidgets('una respuesta antigua no pisa la nueva', (tester) async {
    final h = Harness();
    final old = never<List<FoodSummary>>();
    h.api.onSearchFoods = (q) {
      if (q == 'pl') return old.future;
      return Future.value([sampleSummary(name: 'Pera, cruda')]);
    };
    await h.pumpScreen(tester, const FoodSearchScreen());
    await _type(tester, 'pl');
    await _debounce(tester);
    await _type(tester, 'pera');
    await _debounce(tester);
    old.complete([sampleSummary(name: 'Plátano, crudo')]);
    await tester.pump();
    expect(find.text('Pera, cruda'), findsOneWidget);
    expect(find.text('Plátano, crudo'), findsNothing);
  });

  testWidgets('sin resultados ofrece crear con el nombre escrito', (
    tester,
  ) async {
    final h = Harness();
    await h.pumpScreen(tester, const FoodSearchScreen());
    await _type(tester, 'xyzzy');
    await _debounce(tester);
    expect(find.text('No hemos encontrado “xyzzy”.'), findsOneWidget);
    await tester.tap(find.text('Crear alimento “xyzzy”'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo alimento'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'xyzzy'), findsOneWidget);
  });

  testWidgets('sin conexión conserva el texto y reintenta', (tester) async {
    final h = Harness();
    var fail = true;
    h.api.onSearchFoods = (_) async {
      if (fail) throw const NetworkFailure();
      return [sampleSummary()];
    };
    await h.pumpScreen(tester, const FoodSearchScreen());
    await _type(tester, 'platano');
    await _debounce(tester);
    expect(find.text('Sin conexión. Inténtalo de nuevo.'), findsOneWidget);
    expect(find.text('platano'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Plátano, crudo'), findsOneWidget);
    expect(find.text('platano'), findsOneWidget);
  });

  testWidgets('agrupa por tipo y la fila tiene etiqueta semántica', (
    tester,
  ) async {
    final h = Harness();
    h.api.onSearchFoods = (_) async => [
      sampleSummary(
        id: 'm',
        name: 'Tarta de la abuela',
        kind: FoodKind.custom,
        isMine: true,
        kcal: 320,
      ),
      sampleSummary(id: 'g', name: 'Plátano, crudo'),
      sampleSummary(
        id: 'p',
        name: 'Plátanos de Canarias',
        kind: FoodKind.packaged,
        brand: 'Marca',
        kcal: 95,
      ),
    ];
    await h.pumpScreen(tester, const FoodSearchScreen());
    await _type(tester, 'platano');
    await _debounce(tester);
    expect(find.text('Mis alimentos'), findsNWidgets(2)); // sección y botón
    expect(find.text('Alimentos'), findsWidgets);
    expect(find.text('Productos envasados'), findsOneWidget);
    expect(find.text('Mío'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Tarta de la abuela')).label,
      contains('Tarta de la abuela, 320 kilocalorías por 100 gramos, tuyo'),
    );
    expect(
      tester.getSemantics(find.text('Plátanos de Canarias')).label,
      contains('Plátanos de Canarias, Marca, 95 kilocalorías por 100 gramos'),
    );
    await expectAccessible(tester);
  });

  testWidgets('con el texto al 200 % no desborda', (tester) async {
    final h = Harness();
    h.api.onSearchFoods = (_) async => [
      sampleSummary(
        name: 'Plátano, crudo',
        brand: 'Una marca con nombre muy largo',
      ),
    ];
    await h.pumpScreen(
      tester,
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: const FoodSearchScreen(),
      ),
    );
    await _type(tester, 'platano');
    await _debounce(tester);
    expect(tester.takeException(), isNull);
  });
}
