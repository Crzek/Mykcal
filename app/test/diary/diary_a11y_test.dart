import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/core/theme/app_theme.dart';
import 'package:mykcal/features/diary/diary_screen.dart';
import 'package:mykcal/features/diary/entry_quantity_sheet.dart';
import 'package:mykcal/features/diary/local_day.dart';
import 'package:mykcal/features/diary/summary_detail_sheet.dart';
import 'package:mykcal/l10n/app_localizations.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';
import 'summary_card_test.dart' show target2000;

/// Un día con exceso de kcal y un macro incompleto: los dos estados que no pueden depender
/// solo del color (FR-014).
DiaryDay busyDay() => sampleDay(
  target: target2000,
  entries: [
    sampleEntry(
      id: 'a',
      quantity: 800,
      values: amounts(kcal: 2150, proteinG: 120, carbsG: 150, fatG: 50),
    ),
  ],
  incomplete: const ['carbs_g', 'fiber_g'],
);

Future<void> pumpDiary(WidgetTester tester, {ThemeData? theme}) async {
  await tallScreen(tester);
  final h = Harness();
  h.api.onDiaryDay = (_, _) async => busyDay();
  await tester.pumpWidget(
    ProviderScope(
      overrides: h.overrides,
      child: MaterialApp(
        theme: theme ?? AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DiaryScreen(registeredAt: DateTime(2026, 11, 1))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in {
    'claro': AppTheme.light(),
    'oscuro': AppTheme.dark(),
  }.entries) {
    testWidgets('el diario cumple las guías de accesibilidad (${entry.key})', (
      tester,
    ) async {
      await pumpDiary(tester, theme: entry.value);
      expect(find.byIcon(Icons.warning_amber), findsWidgets);
      expect(find.byIcon(Icons.info_outline), findsWidgets);
      await expectAccessible(tester);
    });
  }

  testWidgets('el diario al 200 % no se corta ni desborda', (tester) async {
    await pumpDiary(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('todos los controles del diario tienen etiqueta', (tester) async {
    await pumpDiary(tester);
    for (final label in [
      'Día anterior',
      'Elegir fecha',
      'Añadir a Desayuno',
      'Añadir a Comida',
      'Añadir a Merienda',
      'Añadir a Cena',
      'Añadir a Picoteo',
    ]) {
      expect(find.byTooltip(label), findsOneWidget, reason: label);
    }
  });

  testWidgets(
    'el exceso y lo incompleto se leen en una frase, no solo por color',
    (tester) async {
      await pumpDiary(tester);
      expect(
        find.bySemanticsLabel(
          RegExp(r'Calorías: 2\.150 de 2\.000 kcal, 150 kcal por encima'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Carbohidratos.*\(incompleto\)')),
        findsOneWidget,
      );
    },
  );

  testWidgets('el detalle del día cumple las guías y aguanta el 200 %', (
    tester,
  ) async {
    await tallScreen(tester);
    await Harness().pumpScreen(
      tester,
      Scaffold(
        body: SingleChildScrollView(child: SummaryDetailSheet(day: busyDay())),
      ),
    );
    await expectAccessible(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('la hoja de cantidad cumple las guías y aguanta el 200 %', (
    tester,
  ) async {
    await tallScreen(tester);
    await Harness().pumpScreen(
      tester,
      Scaffold(
        body: EntryQuantitySheet(
          food: sampleFood(servingSize: 30),
          date: LocalDay.today(testNow),
          meal: Meal.breakfast,
        ),
      ),
    );
    await expectAccessible(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
