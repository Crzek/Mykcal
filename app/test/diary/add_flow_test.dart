import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/diary/diary_screen.dart';
import 'package:mykcal/features/foods/barcode_result_flow.dart';
import 'package:mykcal/features/foods/food_detail_screen.dart';
import 'package:mykcal/features/foods/food_search_controller.dart';
import 'package:mykcal/features/foods/food_search_screen.dart';

import '../helpers/fakes.dart';
import 'summary_card_test.dart' show target2000;

Future<Harness> pumpDiary(WidgetTester tester) async {
  await tallScreen(tester);
  final h = Harness();
  h.api.onDiaryDay = (date, _) async => sampleDay(target: target2000);
  h.api.onSearchFoods = (_) async => [sampleSummary(name: 'Pan integral')];
  h.api.onFood = (_) async => sampleFood(name: 'Pan integral');
  await h.pumpScreen(tester, const Scaffold(body: DiaryScreen()));
  await tester.pumpAndSettle();
  return h;
}

Future<void> search(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'pan');
  await tester.pump(searchDebounce + const Duration(milliseconds: 10));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    '«+» abre la búsqueda en modo selección con el título de la comida',
    (tester) async {
      await pumpDiary(tester);
      await tester.tap(find.byTooltip('Añadir a Desayuno'));
      await tester.pumpAndSettle();
      expect(find.byType(FoodSearchScreen), findsOneWidget);
      expect(find.text('Añadir a Desayuno'), findsOneWidget);
    },
  );

  testWidgets('elegir un resultado abre la hoja y «Añadir» vuelve al diario', (
    tester,
  ) async {
    final h = await pumpDiary(tester);
    h.api.onAddEntry = (call) async => sampleDay(
      target: target2000,
      entries: [sampleEntry(name: 'Pan integral', quantity: 60)],
    );
    await tester.tap(find.byTooltip('Añadir a Desayuno'));
    await tester.pumpAndSettle();
    await search(tester);
    await tester.tap(find.text('Pan integral'));
    await tester.pumpAndSettle();
    expect(find.text('Cantidad'), findsOneWidget); // la hoja, no el detalle
    await tester.enterText(find.widgetWithText(TextField, 'Cantidad'), '60');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Añadir'));
    await tester.pumpAndSettle();
    expect(find.byType(FoodSearchScreen), findsNothing);
    expect(find.text('Añadido a Desayuno'), findsOneWidget);
    expect(find.text('60 g'), findsOneWidget); // el día de la respuesta
    expect(h.api.addedEntries.single.meal, Meal.breakfast);
  });

  testWidgets(
    'el «encontrado» del escáner devuelve el alimento en modo selección',
    (tester) async {
      final h = Harness();
      h.api.onBarcode = (c) async => BarcodeLookup(
        result: BarcodeResult.found,
        code: c,
        food: sampleFood(name: 'Galletas', kind: FoodKind.packaged),
      );
      Food? picked;
      await h.pumpScreen(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: FilledButton(
              onPressed: () => lookupAndShowBarcode(
                context,
                ref,
                '8410000000016',
                onSelected: (food) => picked = food,
              ),
              child: const Text('Escanear'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Escanear'));
      await tester.pumpAndSettle();
      expect(picked?.name, 'Galletas');
      expect(find.byType(FoodDetailScreen), findsNothing);
    },
  );
}
