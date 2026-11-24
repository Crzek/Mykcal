import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/features/target/target_edit_screen.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<Harness> open(WidgetTester tester) async {
  await tallScreen(tester);
  final h = Harness();
  await h.pumpScreen(tester, const TargetEditScreen(initial: sampleValues));
  return h;
}

void main() {
  testWidgets('12 campos con su unidad y accesible', (tester) async {
    await open(tester);
    expect(find.byType(TextFormField), findsNWidgets(12));
    expect(
      tester.widget<TextFormField>(field('Calorías')).controller!.text,
      '2759',
    );
    expect(find.text('µg'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets(
    'aviso de macros en vivo sin bloquear «Guardar» (FR-017, US3.4)',
    (tester) async {
      final h = await open(tester);
      expect(find.textContaining('no coinciden'), findsNothing);
      await tester.enterText(field('Calorías'), '2000');
      await tester.pump();
      expect(
        find.text(
          'Las calorías de tus macros (2.761 kcal) no coinciden con tu objetivo (2.000 kcal).',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(h.api.savedTargets.single.kcal, 2000);
      expect(h.api.savedTargets.single.proteinG, 144); // lo demás no cambia
    },
  );

  testWidgets('vacío, negativo o decimal se rechazan junto al campo', (
    tester,
  ) async {
    final h = await open(tester);
    await tester.enterText(field('Proteína'), '');
    await tester.enterText(field('Grasa'), '-3');
    await tester.enterText(field('Fibra'), '2.5');
    await tester.enterText(field('Calorías'), '0');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un número entero de 0 o más'), findsNWidgets(3));
    expect(find.text('Escribe un número entero de 1 o más'), findsOneWidget);
    expect(h.api.savedTargets, isEmpty);
  });

  testWidgets('sin conexión: aviso y los valores se conservan', (tester) async {
    final h = await open(tester);
    h.api.onSaveTarget = (_) async => throw const NetworkFailure();
    await tester.enterText(field('Calorías'), '2500');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión. Inténtalo de nuevo.'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(field('Calorías')).controller!.text,
      '2500',
    );
  });
}
