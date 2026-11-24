import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/diary/entry_quantity_sheet.dart';
import 'package:mykcal/features/diary/local_day.dart';

import '../helpers/fakes.dart';

final day = LocalDay.today(testNow);

Future<Harness> pumpSheet(WidgetTester tester, Food food) async {
  await tallScreen(tester);
  final h = Harness();
  await h.pumpScreen(
    tester,
    Scaffold(
      body: EntryQuantitySheet(food: food, date: day, meal: Meal.breakfast),
    ),
  );
  return h;
}

Food bread({double? serving}) => sampleFood(
  name: 'Pan integral',
  servingSize: serving,
  per100: const Nutrients(kcal: 250, proteinG: 9, carbsG: 42, fatG: 3),
);

Finder get addButton => find.widgetWithText(FilledButton, 'Añadir');

void main() {
  testWidgets('con ración: «raciones» por defecto con 1 y la equivalencia', (
    tester,
  ) async {
    await pumpSheet(tester, bread(serving: 30));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '1',
    );
    expect(find.text('1 ración = 30 g'), findsOneWidget);
    expect(find.text('75 kcal · P 2,7 · C 12,6 · G 0,9 g'), findsOneWidget);
  });

  testWidgets('sin ración: g con el campo vacío, enfocado y «Añadir» apagado', (
    tester,
  ) async {
    await pumpSheet(tester, bread());
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    expect(field.autofocus, isTrue);
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(tester.widget<FilledButton>(addButton).onPressed, isNull);
  });

  testWidgets('la vista previa cambia al escribir y coincide con entry_math', (
    tester,
  ) async {
    await pumpSheet(tester, bread());
    await tester.enterText(find.byType(TextField), '60');
    await tester.pump();
    expect(find.text('150 kcal · P 5,4 · C 25,2 · G 1,8 g'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '100,5');
    await tester.pump();
    expect(find.text('251 kcal · P 9 · C 42,2 · G 3 g'), findsOneWidget);
  });

  testWidgets('vacío, 0 o negativo: aviso y botón desactivado', (tester) async {
    await pumpSheet(tester, bread());
    for (final text in ['', '0', '-5', 'abc']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      expect(
        find.text('Indica una cantidad mayor que 0'),
        findsOneWidget,
        reason: text,
      );
      expect(
        tester.widget<FilledButton>(addButton).onPressed,
        isNull,
        reason: text,
      );
    }
  });

  testWidgets('más de 10.000: «Máximo 10.000»', (tester) async {
    await pumpSheet(tester, bread());
    await tester.enterText(find.byType(TextField), '10001');
    await tester.pump();
    expect(find.text('Máximo 10.000'), findsOneWidget);
    expect(tester.widget<FilledButton>(addButton).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '10000');
    await tester.pump();
    expect(tester.widget<FilledButton>(addButton).onPressed, isNotNull);
  });

  testWidgets('envía raciones o gramos, nunca los dos', (tester) async {
    final h = await pumpSheet(tester, bread(serving: 30));
    await tester.enterText(find.byType(TextField), '2');
    await tester.pump();
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    final call = h.api.addedEntries.single;
    expect((call.servings, call.quantity), (2.0, null));
    expect(
      (call.meal, call.foodId, call.date),
      (Meal.breakfast, 'food-1', day),
    );
    expect(call.utcOffsetMin, LocalDay.utcOffsetMin(day));
  });

  testWidgets('cambiar a g envía la cantidad en g', (tester) async {
    final h = await pumpSheet(tester, bread(serving: 30));
    await tester.tap(find.text('g'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '45,5');
    await tester.pump();
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    final call = h.api.addedEntries.single;
    expect((call.quantity, call.servings), (45.5, null));
  });

  testWidgets('más de 5.000: pide confirmar; «Cambiar» no envía nada', (
    tester,
  ) async {
    final h = await pumpSheet(tester, bread());
    await tester.enterText(find.byType(TextField), '6000');
    await tester.pump();
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    expect(find.text('¿Seguro? Son 6.000 g'), findsOneWidget);
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();
    expect(h.api.addedEntries, isEmpty);
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, añadir'));
    await tester.pumpAndSettle();
    expect(h.api.addedEntries.single.quantity, 6000);
  });

  testWidgets('sin red: sigue abierta con lo escrito y «Reintentar» lo envía', (
    tester,
  ) async {
    final h = await pumpSheet(tester, bread());
    var fail = true;
    h.api.onAddEntry = (call) async {
      if (fail) throw const NetworkFailure();
      return sampleDay(date: call.date);
    };
    await tester.enterText(find.byType(TextField), '80');
    await tester.pump();
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    expect(
      find.text('Sin conexión. Revisa la red y vuelve a intentarlo'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '80',
    );
    fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(h.api.addedEntries, hasLength(2));
    expect(
      find.text('Sin conexión. Revisa la red y vuelve a intentarlo'),
      findsNothing,
    );
  });
}
