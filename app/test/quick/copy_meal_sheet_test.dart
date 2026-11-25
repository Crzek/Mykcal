import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/diary/diary_screen.dart';

import '../diary/summary_card_test.dart' show target2000;
import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

CopySourceEntry srcEntry(String name, double q, double kcal) =>
    CopySourceEntry(foodName: name, baseUnit: 'g', quantity: q, kcal: kcal);

CopySourceMeal srcMeal(
  Meal meal,
  List<CopySourceEntry> entries, {
  bool changed = false,
}) => CopySourceMeal(
  meal: meal,
  entries: entries,
  kcal: entries.fold(0, (a, e) => a + e.kcal),
  valuesChanged: changed,
);

Future<Harness> pumpCopy(
  WidgetTester tester, {
  List<CopySourceDay>? sources,
}) async {
  await tallScreen(tester);
  final h = Harness();
  h.api.onDiaryDay = (_, _) async => sampleDay(target: target2000);
  final yesterday = DateTime(
    h.diaryNow.year,
    h.diaryNow.month,
    h.diaryNow.day,
  ).subtract(const Duration(days: 1));
  h.api.onCopySources = (_, _) async =>
      sources ??
      [
        CopySourceDay(
          date: yesterday,
          meals: [
            srcMeal(Meal.dinner, [
              srcEntry('Merluza', 150, 300),
              srcEntry('Patata', 200, 160),
              srcEntry('Aceite', 10, 90),
              srcEntry('Pan', 40, 100),
            ]),
            srcMeal(Meal.breakfast, [
              srcEntry('Tostada', 60, 150),
            ], changed: true),
          ],
        ),
      ];
  await h.pumpScreen(tester, const Scaffold(body: DiaryScreen()));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Más opciones de Cena'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Copiar de otro día'));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets(
    'lista días y comidas, la del mismo tipo primero, «Copiar» desactivado',
    (tester) async {
      await pumpCopy(tester);
      expect(find.textContaining('Copiar a Cena'), findsOneWidget);
      expect(find.textContaining('Ayer'), findsOneWidget);
      expect(find.text('Merluza 150 g'), findsOneWidget);
      expect(find.text('+1 más'), findsOneWidget); // 4 entradas, se ven 3
      expect(find.text('Pan 40 g'), findsNothing);
      expect(
        find.text(
          'Algún alimento ha cambiado: se copiará con sus valores actuales.',
        ),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Copiar'),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets('«+N más» despliega las entradas', (tester) async {
    await pumpCopy(tester);
    await tester.tap(find.text('+1 más'));
    await tester.pumpAndSettle();
    expect(find.text('Pan 40 g'), findsOneWidget);
  });

  testWidgets('sin comidas: mensaje de vacío', (tester) async {
    await pumpCopy(tester, sources: const []);
    expect(
      find.text('No hay comidas en los 14 días anteriores.'),
      findsOneWidget,
    );
  });

  testWidgets('elegir y copiar: llama a la API, cierra y ofrece deshacer 5 s', (
    tester,
  ) async {
    final h = await pumpCopy(tester);
    h.api.onCopyMeal = (call) async => DiaryCopyResult(
      copyId: 'copy-9',
      entryIds: const ['a', 'b', 'c', 'd'],
      day: sampleDay(target: target2000),
    );
    await tester.tap(find.text('Merluza 150 g'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Copiar'));
    await tester.pumpAndSettle();
    final call = h.api.copyCalls.single;
    expect(call.sourceMeal, Meal.dinner);
    expect(call.targetMeal, Meal.dinner);
    expect(find.textContaining('Copiar a Cena'), findsNothing); // hoja cerrada
    expect(find.text('4 alimentos copiados a Cena'), findsOneWidget);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 5),
    );
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(h.api.undoneCopies, ['copy-9']);
    expect(find.text('Copia deshecha'), findsOneWidget);
  });

  testWidgets(
    'sin conexión: la hoja sigue abierta con la selección y «Reintentar»',
    (tester) async {
      final h = await pumpCopy(tester);
      h.api.onCopyMeal = (_) async => throw const NetworkFailure();
      await tester.tap(find.text('Merluza 150 g'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Copiar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sin conexión'), findsOneWidget);
      expect(find.textContaining('Copiar a Cena'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Reintentar'), findsOneWidget);
    },
  );

  testWidgets('COPY_SOURCE_EMPTY avisa y no cierra', (tester) async {
    final h = await pumpCopy(tester);
    h.api.onCopyMeal = (_) async =>
        throw const ApiError('COPY_SOURCE_EMPTY', 400);
    await tester.tap(find.text('Merluza 150 g'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Copiar'));
    await tester.pumpAndSettle();
    expect(find.text('Esa comida ya no tiene alimentos.'), findsOneWidget);
  });

  testWidgets('accesible: cada opción se lee entera', (tester) async {
    await pumpCopy(tester);
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Cena de Ayer, .*, 650 kcal, 4 alimentos: Merluza 150 g, Patata 200 g',
        ),
      ),
      findsOneWidget,
    );
    await expectAccessible(tester);
  });
}
