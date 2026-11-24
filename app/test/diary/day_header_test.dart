import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/features/diary/diary_screen.dart';
import 'package:mykcal/features/diary/local_day.dart';

import '../helpers/fakes.dart';
import 'summary_card_test.dart' show target2000;

final today = LocalDay.today(testNow); // domingo 22 nov 2026

Future<Harness> pumpDiary(WidgetTester tester, {DateTime? registeredAt}) async {
  await tallScreen(tester);
  final h = Harness();
  h.api.onDiaryDay = (date, _) async =>
      sampleDay(target: target2000, date: date);
  await h.pumpScreen(
    tester,
    Scaffold(body: DiaryScreen(registeredAt: registeredAt)),
  );
  await tester.pumpAndSettle();
  return h;
}

Finder tip(String message) => find.byTooltip(message);

bool enabled(WidgetTester tester, String message) =>
    tester
        .widget<IconButton>(find.widgetWithIcon(IconButton, _icon[message]!))
        .onPressed !=
    null;

const _icon = {
  'Día anterior': Icons.chevron_left,
  'Día siguiente': Icons.chevron_right,
};

void main() {
  testWidgets('hoy: título «Hoy», «›» desactivado y sin «Ir a hoy» ni aviso', (
    tester,
  ) async {
    await pumpDiary(tester, registeredAt: DateTime(2026, 11, 1));
    expect(find.text('Hoy'), findsOneWidget);
    expect(enabled(tester, 'Día siguiente'), isFalse);
    expect(enabled(tester, 'Día anterior'), isTrue);
    expect(find.text('Ir a hoy'), findsNothing);
    expect(
      find.text('Este día usó el objetivo que tenías entonces'),
      findsNothing,
    );
  });

  testWidgets(
    '«‹» lleva a ayer: título «Ayer», aviso, «Ir a hoy» y pide ese día',
    (tester) async {
      final h = await pumpDiary(tester, registeredAt: DateTime(2026, 11, 1));
      await tester.tap(tip('Día anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Ayer'), findsOneWidget);
      expect(
        find.text('Este día usó el objetivo que tenías entonces'),
        findsOneWidget,
      );
      expect(find.text('Ir a hoy'), findsOneWidget);
      expect(enabled(tester, 'Día siguiente'), isTrue);
      expect(h.api.diaryRequests.last.$1, DateTime(2026, 11, 21));
    },
  );

  testWidgets('antes de ayer: fecha completa «viernes 20 nov»', (tester) async {
    await pumpDiary(tester, registeredAt: DateTime(2026, 11, 1));
    await tester.tap(tip('Día anterior'));
    await tester.pumpAndSettle();
    await tester.tap(tip('Día anterior'));
    await tester.pumpAndSettle();
    expect(find.text('viernes 20 nov'), findsOneWidget);
  });

  testWidgets('«Ir a hoy» y «›» vuelven a hoy', (tester) async {
    await pumpDiary(tester, registeredAt: DateTime(2026, 11, 1));
    await tester.tap(tip('Día anterior'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ir a hoy'));
    await tester.pumpAndSettle();
    expect(find.text('Hoy'), findsOneWidget);
    await tester.tap(tip('Día anterior'));
    await tester.pumpAndSettle();
    await tester.tap(tip('Día siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Hoy'), findsOneWidget);
  });

  testWidgets('«‹» se desactiva en el día del alta', (tester) async {
    await pumpDiary(tester, registeredAt: DateTime(2026, 11, 21, 9));
    await tester.tap(tip('Día anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Ayer'), findsOneWidget); // 21 nov = día del alta
    expect(enabled(tester, 'Día anterior'), isFalse);
  });

  testWidgets('📅 abre el calendario entre el alta y hoy', (tester) async {
    await pumpDiary(tester, registeredAt: DateTime(2026, 11, 10));
    await tester.tap(tip('Elegir fecha'));
    await tester.pumpAndSettle();
    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(picker.firstDate, DateTime(2026, 11, 10));
    expect(picker.lastDate, today);
    await tester.tap(find.text('15'));
    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();
    expect(find.text('domingo 15 nov'), findsOneWidget);
  });

  testWidgets('los botones miden al menos 48 dp y tienen etiqueta', (
    tester,
  ) async {
    await pumpDiary(tester, registeredAt: DateTime(2026, 11, 1));
    for (final label in ['Día anterior', 'Elegir fecha', 'Día siguiente']) {
      final size = tester.getSize(tip(label));
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
  });
}
