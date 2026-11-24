import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/api_errors.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/diary/diary_screen.dart';
import 'package:mykcal/features/diary/local_day.dart';

import '../helpers/fakes.dart';
import 'summary_card_test.dart' show target2000;

DiaryDay dayWithBreakfast() => sampleDay(
  target: target2000,
  entries: [
    sampleEntry(id: 'a', quantity: 60),
    sampleEntry(
      id: 'b',
      name: 'Leche',
      brand: 'Pascual',
      quantity: 250,
      servings: 1,
      servingSize: 250,
      per100: const Nutrients(kcal: 64, proteinG: 3.2, carbsG: 4.8, fatG: 3.6),
    ),
  ],
);

Future<Harness> pumpDiary(WidgetTester tester, {DiaryDay? day}) async {
  await tallScreen(tester);
  final h = Harness();
  h.api.onDiaryDay = (date, _) async => day ?? dayWithBreakfast();
  await h.pumpScreen(tester, const Scaffold(body: DiaryScreen()));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('las 5 comidas en orden con su total y sus entradas', (
    tester,
  ) async {
    await pumpDiary(tester);
    final order = [
      'Desayuno',
      'Comida',
      'Merienda',
      'Cena',
      'Picoteo',
    ].map((m) => tester.getTopLeft(find.text(m)).dy).toList();
    expect([...order]..sort(), order);
    expect(find.text('Pan integral'), findsOneWidget);
    expect(find.text('60 g'), findsOneWidget);
    expect(find.text('Leche'), findsOneWidget);
    expect(find.text('Pascual'), findsOneWidget);
    expect(find.text('1 ración · 250 g'), findsOneWidget);
    expect(find.text('Aún no hay nada'), findsNWidgets(4));
    // Total de Desayuno: 150 + 160 kcal
    expect(find.text('310 kcal'), findsWidgets);
  });

  testWidgets('día sin entradas: las cinco comidas vacías', (tester) async {
    await pumpDiary(tester, day: sampleDay(target: target2000));
    expect(find.text('Aún no hay nada'), findsNWidgets(5));
    expect(find.text('Quedan 2.000 kcal'), findsOneWidget);
  });

  testWidgets('pide hoy con el desfase de su zona', (tester) async {
    final h = await pumpDiary(tester);
    final (date, offset) = h.api.diaryRequests.first;
    expect(date, LocalDay.today(testNow));
    expect(offset, LocalDay.utcOffsetMin(date));
  });

  testWidgets('un fallo de red muestra «Reintentar» y se recupera', (
    tester,
  ) async {
    await tallScreen(tester);
    final h = Harness();
    h.api.onDiaryDay = (_, _) async => throw const NetworkFailure();
    await h.pumpScreen(tester, const Scaffold(body: DiaryScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Necesitas conexión a Internet.'), findsOneWidget);
    h.api.onDiaryDay = (_, _) async => dayWithBreakfast();
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Pan integral'), findsOneWidget);
  });

  testWidgets('«Ver detalle» abre fibra y micros', (tester) async {
    await pumpDiary(tester);
    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();
    expect(find.text('Fibra y micronutrientes'), findsOneWidget);
    expect(find.text('Vitamina C'), findsOneWidget);
  });

  testWidgets('«Ver objetivo» abre la pantalla del objetivo', (tester) async {
    await pumpDiary(tester);
    await tester.tap(find.text('Ver objetivo'));
    await tester.pumpAndSettle();
    expect(find.text('Tu objetivo diario'), findsOneWidget);
  });
}
