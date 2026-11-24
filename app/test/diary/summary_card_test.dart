import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/diary/summary_card.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

const target2000 = TargetValues(
  kcal: 2000,
  proteinG: 150,
  carbsG: 200,
  fatG: 56,
  fiberG: 25,
  sodiumMg: 2300,
  potassiumMg: 3500,
  calciumMg: 1000,
  ironMg: 8,
  magnesiumMg: 400,
  vitaminDUg: 15,
  vitaminCMg: 90,
);

DiaryEntry eaten({
  double kcal = 1850,
  double protein = 120,
  double carbs = 150,
  double fat = 50,
}) => sampleEntry(
  values: amounts(kcal: kcal, proteinG: protein, carbsG: carbs, fatG: fat),
);

Future<void> pumpCard(
  WidgetTester tester,
  DiaryDay day, {
  VoidCallback? onDetail,
  VoidCallback? onTarget,
}) => Harness().pumpScreen(
  tester,
  Scaffold(
    body: SingleChildScrollView(
      child: SummaryCard(
        day: day,
        onDetail: onDetail ?? () {},
        onTarget: onTarget ?? () {},
      ),
    ),
  ),
);

void main() {
  testWidgets('muestra consumido, objetivo y restante de kcal y macros', (
    tester,
  ) async {
    await pumpCard(tester, sampleDay(target: target2000, entries: [eaten()]));
    expect(find.text('Calorías'), findsOneWidget);
    expect(find.text('1.850 / 2.000 kcal'), findsOneWidget);
    expect(find.text('Quedan 150 kcal'), findsOneWidget);
    expect(find.text('120 / 150 g'), findsOneWidget);
    expect(find.text('Quedan 30 g'), findsOneWidget);
    expect(find.text('Proteína'), findsOneWidget);
    expect(find.text('Carbohidratos'), findsOneWidget);
    expect(find.text('Grasa'), findsOneWidget);
    expect(find.text('Quedan 6 g'), findsOneWidget);
  });

  testWidgets('día vacío: consumido 0 y el objetivo completo como restante', (
    tester,
  ) async {
    await pumpCard(tester, sampleDay(target: target2000));
    expect(find.text('0 / 2.000 kcal'), findsOneWidget);
    expect(find.text('Quedan 2.000 kcal'), findsOneWidget);
  });

  testWidgets('exceso: «+150 kcal» con icono y texto, no solo color', (
    tester,
  ) async {
    await pumpCard(
      tester,
      sampleDay(target: target2000, entries: [eaten(kcal: 2150)]),
    );
    expect(find.textContaining('+150 kcal'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    expect(find.text('Quedan 150 kcal'), findsNothing);
    // El lector de pantalla oye una sola frase.
    expect(
      find.bySemanticsLabel(
        'Calorías: 2.150 de 2.000 kcal, 150 kcal por encima',
      ),
      findsOneWidget,
    );
    final text = tester.widget<Text>(find.textContaining('+150 kcal'));
    final scheme = Theme.of(tester.element(find.byType(SummaryCard)))
        .colorScheme;
    expect(text.style?.color, scheme.error);
  });

  testWidgets('la frase del lector de pantalla dice cuánto queda', (
    tester,
  ) async {
    await pumpCard(tester, sampleDay(target: target2000, entries: [eaten()]));
    expect(
      find.bySemanticsLabel('Calorías: 1.850 de 2.000 kcal, quedan 150 kcal'),
      findsOneWidget,
    );
  });

  testWidgets('un macro incompleto lleva «incompleto» con icono', (
    tester,
  ) async {
    await pumpCard(
      tester,
      sampleDay(
        target: target2000,
        entries: [eaten()],
        incomplete: const ['carbs_g'],
      ),
    );
    expect(find.text('incompleto'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('las barras son decorativas para el lector de pantalla', (
    tester,
  ) async {
    await pumpCard(tester, sampleDay(target: target2000, entries: [eaten()]));
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('progreso|%')), findsNothing);
    handle.dispose();
  });

  testWidgets('«Ver detalle» y «Ver objetivo» llaman a sus acciones', (
    tester,
  ) async {
    var detail = 0;
    var targetOpened = 0;
    await pumpCard(
      tester,
      sampleDay(target: target2000),
      onDetail: () => detail++,
      onTarget: () => targetOpened++,
    );
    await tester.tap(find.text('Ver detalle'));
    await tester.tap(find.text('Ver objetivo'));
    expect(detail, 1);
    expect(targetOpened, 1);
    await expectAccessible(tester);
  });
}
