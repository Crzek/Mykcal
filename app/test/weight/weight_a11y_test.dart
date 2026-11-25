import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/core/theme/app_theme.dart';
import 'package:mykcal/features/weight/recalc_proposal_dialog.dart';
import 'package:mykcal/features/weight/weight_screen.dart';
import 'package:mykcal/l10n/app_localizations.dart';

import '../helpers/a11y.dart';
import '../helpers/fakes.dart';

Future<void> pumpWeight(WidgetTester tester, ThemeData theme) async {
  await tallScreen(tester);
  final h = Harness();
  h.api.onWeightEntries = () async => [
    WeightEntry(measuredOn: DateTime(2026, 11, 22), weightKg: 78.0),
    WeightEntry(measuredOn: DateTime(2026, 11, 21), weightKg: 78.5),
  ];
  h.api.onWeightChart = (period) async => WeightChart(
    period: period,
    points: [
      WeightChartPoint(date: DateTime(2026, 11, 20), weightKg: 79.0),
      WeightChartPoint(
        date: DateTime(2026, 11, 22),
        weightKg: 78.0,
        averageKg: 78.5,
      ),
    ],
    summary: const WeightChartSummary(
      count: 2,
      currentWeightKg: 78.0,
      weeklyAverageKg: 78.5,
      changeKg: -1.0,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: h.overrides,
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WeightScreen(registeredAt: DateTime(2026, 11, 1)),
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
    testWidgets('la pantalla de peso cumple las guías (${entry.key})', (
      tester,
    ) async {
      await pumpWeight(tester, entry.value);
      await expectAccessible(tester);
    });

    testWidgets('el diálogo de propuesta cumple las guías (${entry.key})', (
      tester,
    ) async {
      final h = Harness();
      await tester.pumpWidget(
        ProviderScope(
          overrides: h.overrides,
          child: MaterialApp(
            theme: entry.value,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showRecalcProposalDialog(
                    context,
                    RecalcProposal(
                      pending: true,
                      referenceWeightKg: 80,
                      weeklyAverageKg: 78.2,
                      wasManual: true,
                      largeChange: true,
                      current: sampleValues,
                      proposed: losingValues,
                    ),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await expectAccessible(tester);
    });
  }

  testWidgets('texto al 200% sin desbordes en la pantalla de peso', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpWeight(tester, AppTheme.light());
    expect(tester.takeException(), isNull);
  });
}
