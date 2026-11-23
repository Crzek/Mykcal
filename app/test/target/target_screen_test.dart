import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/features/target/target_screen.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

void main() {
  testWidgets('modo resultado: kcal, macros, fibra y micros con mínimo/máximo (US2.1)', (tester) async {
    await tallScreen(tester);
    final h = Harness();
    await h.pumpScreen(tester, TargetScreen(result: sampleTarget()));
    expect(find.text('2.759 kcal'), findsOneWidget);
    expect(find.text('144 g'), findsOneWidget);
    expect(find.text('373 g'), findsOneWidget);
    expect(find.text('77 g'), findsOneWidget);
    for (final nutrient in [
      'Fibra', 'Sodio', 'Potasio', 'Calcio', 'Hierro', 'Magnesio', 'Vitamina D', 'Vitamina C',
    ]) {
      expect(find.text(nutrient), findsOneWidget, reason: nutrient);
    }
    expect(find.text('2.000 mg'), findsOneWidget);
    expect(find.text('máximo'), findsOneWidget); // solo el sodio
    expect(find.text('mínimo'), findsNWidgets(7));
    expect(find.text('Empezar'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
    await expectAccessible(tester);
  });

  testWidgets('avisos del cálculo con icono y texto', (tester) async {
    await tallScreen(tester);
    final h = Harness();
    await h.pumpScreen(
      tester,
      TargetScreen(
        result: sampleTarget(
          sex: 'female',
          notices: const ['MIN_KCAL_APPLIED', 'CARBS_CLAMPED'],
        ),
      ),
    );
    expect(find.text('Hemos subido tus calorías al mínimo seguro de 1.200 kcal.'), findsOneWidget);
    expect(find.textContaining('el objetivo no es coherente'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsNWidgets(2));
  });

  testWidgets('detalle calculado: «Editar» y sin «Volver al cálculo»', (tester) async {
    await tallScreen(tester);
    final h = Harness();
    await h.pumpScreen(tester, const TargetScreen());
    await tester.pumpAndSettle();
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Editado a mano'), findsNothing);
    expect(find.text('Volver al cálculo'), findsNothing);
  });

  testWidgets('detalle manual: marca «Editado a mano» y vuelve al cálculo con confirmación (US3.3)', (tester) async {
    await tallScreen(tester);
    final h = Harness();
    h.api.onTarget = () async => sampleTarget(manual: true);
    await h.pumpScreen(tester, const TargetScreen());
    await tester.pumpAndSettle();
    expect(find.text('Editado a mano'), findsOneWidget);

    await tester.tap(find.text('Volver al cálculo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(h.api.recalculateCalls, 0);

    await tester.tap(find.text('Volver al cálculo'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Volver al cálculo')));
    await tester.pumpAndSettle();
    expect(h.api.recalculateCalls, 1);
    expect(find.text('Objetivo recalculado'), findsOneWidget);
  });
}
