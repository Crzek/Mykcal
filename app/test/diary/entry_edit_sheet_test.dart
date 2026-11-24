import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/diary/diary_screen.dart';

import '../helpers/fakes.dart';
import 'summary_card_test.dart' show target2000;

/// Entrada de 2 raciones de 30 g (60 g), con la copia de 250 kcal/100 g.
DiaryEntry servingsEntry() => sampleEntry(
  id: 'e1',
  name: 'Pan integral',
  quantity: 60,
  servings: 2,
  servingSize: 30,
);

Future<Harness> pumpEdit(
  WidgetTester tester,
  DiaryEntry entry, {
  Food? currentFood,
}) async {
  await tallScreen(tester);
  final h = Harness();
  h.api.onDiaryDay = (date, _) async =>
      sampleDay(target: target2000, entries: [entry]);
  // El alimento actual vale otra cosa: la hoja no debe usarlo (FR-004).
  h.api.onFood = (_) async => currentFood ?? sampleFood();
  await h.pumpScreen(tester, const Scaffold(body: DiaryScreen()));
  await tester.pumpAndSettle();
  await tester.tap(find.text(entry.foodName));
  await tester.pumpAndSettle();
  return h;
}

Finder get field => find.widgetWithText(TextField, 'Cantidad');

void main() {
  testWidgets(
    'una entrada en raciones se abre en raciones y permite pasar a g',
    (tester) async {
      await pumpEdit(tester, servingsEntry());
      expect(tester.widget<TextField>(field).controller!.text, '2');
      expect(find.text('1 ración = 30 g'), findsOneWidget);
      await tester.tap(find.text('g'));
      await tester.pump();
      expect(find.text('1 ración = 30 g'), findsNothing);
    },
  );

  testWidgets('guardar en g deja la entrada en g y envía PATCH', (
    tester,
  ) async {
    final h = await pumpEdit(tester, servingsEntry());
    await tester.tap(find.text('g'));
    await tester.pump();
    await tester.enterText(field, '45');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    final call = h.api.updatedEntries.single;
    expect(
      (call.id, call.quantity, call.servings, call.meal),
      ('e1', 45.0, null, null),
    );
  });

  testWidgets('cambiar solo las raciones envía servings', (tester) async {
    final h = await pumpEdit(tester, servingsEntry());
    await tester.enterText(field, '3');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    final call = h.api.updatedEntries.single;
    expect((call.servings, call.quantity), (3.0, null));
  });

  testWidgets(
    'la vista previa usa la copia de la entrada, no el alimento actual',
    (tester) async {
      await pumpEdit(
        tester,
        servingsEntry(),
        currentFood: sampleFood(
          per100: const Nutrients(kcal: 1, proteinG: 0, carbsG: 0, fatG: 0),
        ),
      );
      // 60 g de 250 kcal/100 g, 9 P, 42 C, 3 G
      expect(find.text('150 kcal · P 5,4 · C 25,2 · G 1,8 g'), findsOneWidget);
    },
  );

  testWidgets(
    'el selector de comida ofrece las 5 y mover envía solo la comida',
    (tester) async {
      final h = await pumpEdit(tester, servingsEntry());
      await tester.tap(find.byType(DropdownButtonFormField<Meal>));
      await tester.pumpAndSettle();
      for (final name in [
        'Desayuno',
        'Comida',
        'Merienda',
        'Cena',
        'Picoteo',
      ]) {
        expect(find.text(name), findsWidgets, reason: name);
      }
      await tester.tap(find.text('Cena').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      final call = h.api.updatedEntries.single;
      expect(
        (call.meal, call.quantity, call.servings),
        (Meal.dinner, null, null),
      );
    },
  );

  testWidgets('sin cambios, «Guardar» cierra sin llamar a la API', (
    tester,
  ) async {
    final h = await pumpEdit(tester, servingsEntry());
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(h.api.updatedEntries, isEmpty);
    expect(find.text('Guardar'), findsNothing);
  });

  testWidgets('«Borrar» envía DELETE y cierra la hoja', (tester) async {
    final h = await pumpEdit(tester, servingsEntry());
    await tester.tap(find.widgetWithText(OutlinedButton, 'Borrar'));
    await tester.pumpAndSettle();
    expect(h.api.deletedEntries, ['e1']);
    expect(find.text('Guardar'), findsNothing);
  });

  testWidgets(
    'sin red, «Guardar» y «Borrar» mantienen la hoja con lo escrito',
    (tester) async {
      final h = await pumpEdit(tester, servingsEntry());
      h.api.onUpdateEntry = (_) async => throw const NetworkFailure();
      h.api.onDeleteEntry = (_, _) async => throw const NetworkFailure();
      await tester.enterText(field, '5');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Sin conexión. Revisa la red y vuelve a intentarlo'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(field).controller!.text, '5');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Borrar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Sin conexión. Revisa la red y vuelve a intentarlo'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsWidgets);
      expect(tester.widget<TextField>(field).controller!.text, '5');
    },
  );
}
