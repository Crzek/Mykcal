import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

RecalcProposal pending({bool manual = false, bool large = false}) =>
    RecalcProposal(
      pending: true,
      referenceWeightKg: 80,
      weeklyAverageKg: 78.2,
      wasManual: manual,
      largeChange: large,
      current: sampleValues,
      proposed: losingValues,
    );

Future<Harness> open(WidgetTester tester, {RecalcProposal? proposal}) async {
  final h = Harness();
  await seedSession();
  h.api.onRecalcProposal = () async =>
      proposal ?? const RecalcProposal(pending: false);
  await h.pumpApp(tester);
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('con propuesta pendiente se muestra actual y propuesto', (
    tester,
  ) async {
    await open(tester, proposal: pending());
    expect(find.text('¿Recalcular tu objetivo?'), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    Finder inDialog(String text) =>
        find.descendant(of: dialog, matching: find.textContaining(text));
    expect(inDialog('2.759 kcal'), findsOneWidget);
    expect(inDialog('2.207 kcal'), findsOneWidget);
    expect(inDialog('78,2 kg'), findsOneWidget);
    expect(
      find.text('Aceptar sustituirá los valores que editaste.'),
      findsNothing,
    );
    await expectAccessible(tester);
  });

  testWidgets('Aceptar llama a acceptRecalc y muestra antes → ahora', (
    tester,
  ) async {
    final h = Harness();
    await seedSession();
    h.api.onRecalcProposal = () async => pending();
    h.api.onAcceptRecalc = () async => sampleTarget(values: losingValues);
    await h.pumpApp(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Aceptar'));
    await tester.pumpAndSettle();
    expect(h.api.acceptRecalcCalls, 1);
    expect(find.text('Tu objetivo se ha actualizado'), findsOneWidget);
    expect(find.textContaining('2.207 kcal'), findsOneWidget);
  });

  testWidgets('Ignorar llama a ignoreRecalc y no reaparece', (tester) async {
    final h = Harness();
    await seedSession();
    h.api.onRecalcProposal = () async => pending();
    await h.pumpApp(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Ignorar'));
    await tester.pumpAndSettle();
    expect(h.api.ignoreRecalcCalls, 1);
    expect(find.text('¿Recalcular tu objetivo?'), findsNothing);
    expect(h.api.recalcChecks, 1);
  });

  testWidgets('cerrar sin responder no llama a la API', (tester) async {
    final h = Harness();
    await seedSession();
    h.api.onRecalcProposal = () async => pending();
    await h.pumpApp(tester);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(2, 2)); // fuera del diálogo
    await tester.pumpAndSettle();
    expect(find.text('¿Recalcular tu objetivo?'), findsNothing);
    expect(h.api.acceptRecalcCalls, 0);
    expect(h.api.ignoreRecalcCalls, 0);
  });

  testWidgets('sin propuesta no aparece nada', (tester) async {
    final h = await open(tester);
    expect(find.text('¿Recalcular tu objetivo?'), findsNothing);
    expect(h.api.recalcChecks, 1);
  });

  testWidgets('avisos de objetivo editado a mano y de variación grande', (
    tester,
  ) async {
    await open(tester, proposal: pending(manual: true, large: true));
    expect(
      find.text('Aceptar sustituirá los valores que editaste.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'La variación es muy grande. Revisa si hay un registro erróneo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('RECALC_NO_PROPOSAL al aceptar se trata como ya resuelta', (
    tester,
  ) async {
    final h = Harness();
    await seedSession();
    h.api.onRecalcProposal = () async => pending();
    h.api.onAcceptRecalc = () async =>
        throw const ApiError('RECALC_NO_PROPOSAL', 409);
    await h.pumpApp(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Aceptar'));
    await tester.pumpAndSettle();
    expect(find.text('Algo ha fallado. Inténtalo de nuevo.'), findsNothing);
    expect(find.text('Tu objetivo se ha actualizado'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
