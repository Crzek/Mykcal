import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/features/diary/diary_screen.dart';
import 'package:mykcal/features/diary/local_day.dart';

import '../helpers/fakes.dart';
import 'summary_card_test.dart' show target2000;

Future<Harness> pumpDiary(WidgetTester tester) async {
  await tallScreen(tester);
  final h = Harness();
  h.api.onDiaryDay = (date, _) async =>
      sampleDay(target: target2000, date: date);
  await h.pumpScreen(
    tester,
    Scaffold(body: DiaryScreen(registeredAt: DateTime(2026, 11, 1))),
  );
  await tester.pumpAndSettle();
  return h;
}

Future<void> resume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('en «hoy», al volver tras la medianoche pasa al día nuevo', (
    tester,
  ) async {
    final h = await pumpDiary(tester);
    expect(h.api.diaryRequests.last.$1, DateTime(2026, 11, 22));
    h.diaryNow = testNow.add(const Duration(days: 1));
    await resume(tester);
    expect(h.api.diaryRequests.last.$1, DateTime(2026, 11, 23));
    expect(find.text('Hoy'), findsOneWidget);
  });

  testWidgets('en un día pasado, volver tras la medianoche no lo cambia', (
    tester,
  ) async {
    final h = await pumpDiary(tester);
    await tester.tap(find.byTooltip('Día anterior'));
    await tester.pumpAndSettle();
    h.diaryNow = testNow.add(const Duration(days: 1));
    await resume(tester);
    expect(h.api.diaryRequests.last.$1, DateTime(2026, 11, 21));
    expect(find.text('Ayer'), findsNothing); // ahora es anteayer
    expect(find.text('Ir a hoy'), findsOneWidget);
  });

  testWidgets('sin cambio de fecha, volver no recarga ni mueve nada', (
    tester,
  ) async {
    final h = await pumpDiary(tester);
    final calls = h.api.diaryRequests.length;
    await resume(tester);
    expect(h.api.diaryRequests.length, calls);
    expect(find.text('Hoy'), findsOneWidget);
  });

  testWidgets('añadir en un día pasado usa esa fecha y no cambia hoy (US4.2)', (
    tester,
  ) async {
    final h = await pumpDiary(tester);
    h.api.onSearchFoods = (_) async => [sampleSummary(name: 'Pan')];
    h.api.onFood = (_) async => sampleFood(name: 'Pan');
    await tester.tap(find.byTooltip('Día anterior'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Añadir a Cena'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pan');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Cantidad'), '50');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Añadir'));
    await tester.pumpAndSettle();
    expect(h.api.addedEntries.single.date, DateTime(2026, 11, 21));
    // Al volver a hoy se pide hoy otra vez: el estado de hoy no se tocó.
    await tester.tap(find.text('Ir a hoy'));
    await tester.pumpAndSettle();
    expect(
      LocalDay.sameDay(h.api.diaryRequests.last.$1, DateTime(2026, 11, 22)),
      isTrue,
    );
  });
}
