import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/photo/draft_model.dart';
import 'package:mykcal/features/photo/proposal_edit_screen.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

PhotoDraft proposalDraft({bool unmatched = true}) => PhotoDraft(
  id: 'p1',
  meal: Meal.lunch,
  entryDate: DateTime(2026, 11, 25),
  photoPath: photoPath,
  createdAt: DateTime.utc(2026, 11, 25, 13),
).withProposal(sampleProposal(unmatched: unmatched));

Future<Harness> pump(WidgetTester tester, {PhotoDraft? draft}) async {
  await tallScreen(tester);
  final h = Harness();
  h.api.onSearchFoods = (_) async => [
    sampleSummary(id: 'yog', name: 'Yogur natural'),
  ];
  h.api.onFood = (id) async => sampleFood(
    id: id,
    name: id == 'yog' ? 'Yogur natural' : 'Plátano, crudo',
    per100: const Nutrients(kcal: 60, proteinG: 4, carbsG: 5, fatG: 3),
  );
  await h.pumpScreen(
    tester,
    ProposalEditScreen(draft: draft ?? proposalDraft()),
  );
  return h;
}

void main() {
  testWidgets('muestra el nombre de la IA, el de la base y las kcal', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Arroz blanco cocido (IA)'), findsOneWidget);
    expect(find.text('Arroz, blanco, cocido'), findsOneWidget);
    expect(find.text('150 g · 195 kcal'), findsOneWidget);
    expect(find.text('Sin equivalente en tu base'), findsOneWidget);
    expect(
      find.text('Total: 195 kcal · P 4 g · H 42 g · G 0,5 g'),
      findsOneWidget,
    );
    await expectAccessible(tester);
  });

  testWidgets('sin pareja no se puede guardar', (tester) async {
    await pump(tester);
    final save = find.widgetWithText(FilledButton, 'Guardar en Comida');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
  });

  testWidgets('cambiar los gramos recalcula los totales', (tester) async {
    await pump(tester, draft: proposalDraft(unmatched: false));
    await tester.tap(find.text('150 g · 195 kcal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '300');
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    expect(find.text('300 g · 390 kcal'), findsOneWidget);
    expect(
      find.text('Total: 390 kcal · P 8 g · H 84 g · G 1 g'),
      findsOneWidget,
    );
  });

  testWidgets('quitar un alimento lo saca de la lista', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Quitar').last);
    await tester.pumpAndSettle();
    expect(find.text('Yogur griego con miel (IA)'), findsNothing);
    final save = find.widgetWithText(FilledButton, 'Guardar en Comida');
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  });

  testWidgets('«Buscar» sustituye un alimento sin pareja y deja guardar', (
    tester,
  ) async {
    final h = await pump(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'yogur');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yogur natural'));
    await tester.pumpAndSettle();
    expect(find.text('Sin equivalente en tu base'), findsNothing);
    expect(find.text('Yogur natural'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar en Comida'));
    await tester.pumpAndSettle();
    expect(h.api.addedEntries.map((e) => (e.foodId, e.quantity, e.meal)), [
      ('rice', 150.0, Meal.lunch),
      ('yog', 120.0, Meal.lunch),
    ]);
  });

  testWidgets('«Crear» abre el formulario con el nombre de la IA', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Crear'));
    await tester.pumpAndSettle();
    expect(
      find.text('Yogur griego con miel'),
      findsOneWidget,
    ); // campo precargado
  });

  testWidgets('guardar crea una entrada por alimento y elimina el borrador', (
    tester,
  ) async {
    final h = await pump(tester, draft: proposalDraft(unmatched: false));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar en Comida'));
    // Borrar el borrador usa el almacenamiento local (futuros reales).
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(); // sin pumpAndSettle: el aviso se retiraría solo
    final entry = h.api.addedEntries.single;
    expect(entry.foodId, 'rice');
    expect(entry.quantity, 150);
    expect(entry.date, DateTime(2026, 11, 25));
    expect(find.text('Platos guardados en Comida'), findsOneWidget);
  });
}
