import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/photo/draft_model.dart';
import 'package:mykcal/features/photo/drafts_screen.dart';
import 'package:mykcal/features/photo/drafts_store.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

PhotoDraft draft(String id, String? code, {PhotoAnalysisResult? proposal}) {
  final d = PhotoDraft(
    id: id,
    meal: Meal.breakfast,
    entryDate: DateTime(2026, 11, 25),
    photoPath: '/no/existe/$id.jpg',
    createdAt: DateTime.utc(2026, 11, 25, 8),
  );
  return proposal != null ? d.withProposal(proposal) : d.withFailure(code!);
}

void main() {
  testWidgets('vacío: «No tienes borradores.»', (tester) async {
    final h = Harness();
    await h.pumpScreen(tester, const DraftsScreen());
    expect(find.text('No tienes borradores.'), findsOneWidget);
  });

  testWidgets('cada borrador muestra comida, día, causa y las tres acciones', (
    tester,
  ) async {
    final h = Harness();
    await tester.runAsync(() => DraftsStore().save(draft('a', 'key_invalid')));
    await h.pumpScreen(tester, const DraftsScreen());
    await tester.pumpAndSettle();
    expect(find.text('Desayuno · 25 nov 2026'), findsOneWidget);
    expect(find.textContaining('Tu clave de IA no es válida'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Añadir a mano'), findsOneWidget);
    expect(find.text('Descartar'), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('reintentar vuelve a enviar la foto', (tester) async {
    final h = Harness();
    await tester.runAsync(() => DraftsStore().save(draft('a', 'timeout')));
    h.api.onAnalyzePhoto = (_) async => sampleProposal();
    await h.pumpScreen(tester, const DraftsScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(h.api.analyzeCalls, hasLength(1));
    expect(find.text('Análisis listo'), findsOneWidget);
  });

  testWidgets('descartar pide confirmación y el borrador desaparece', (
    tester,
  ) async {
    final h = Harness();
    await tester.runAsync(() => DraftsStore().save(draft('a', 'timeout')));
    await h.pumpScreen(tester, const DraftsScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar el borrador?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Desayuno · 25 nov 2026'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Descartar').last);
    // El almacenamiento local usa futuros reales: se les deja terminar.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('No tienes borradores.'), findsOneWidget);
    expect(await tester.runAsync(() => DraftsStore().list()), isEmpty);
  });

  testWidgets('una propuesta lista se puede revisar', (tester) async {
    final h = Harness();
    await tester.runAsync(
      () => DraftsStore().save(draft('a', null, proposal: sampleProposal())),
    );
    await h.pumpScreen(tester, const DraftsScreen());
    await tester.pumpAndSettle();
    expect(find.text('Análisis listo'), findsOneWidget);
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();
    expect(find.text('Arroz, blanco, cocido'), findsOneWidget);
  });

  testWidgets('con el texto al 200 % no desborda', (tester) async {
    await tallScreen(tester);
    final h = Harness();
    await tester.runAsync(
      () => DraftsStore().save(draft('a', 'quota_exceeded')),
    );
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await h.pumpScreen(tester, const DraftsScreen());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
