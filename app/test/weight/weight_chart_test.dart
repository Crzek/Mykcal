import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/weight/weight_screen.dart';

import '../helpers/fakes.dart';

WeightChart chartOf(String period, {int points = 3}) => WeightChart(
  period: period,
  points: [
    for (var i = 0; i < points; i++)
      WeightChartPoint(
        date: DateTime(2026, 11, 20 + i),
        weightKg: 79.0 - i * 0.5,
        averageKg: i == points - 1 && points >= 3 ? 78.5 : null,
      ),
  ],
  summary: WeightChartSummary(
    count: points,
    currentWeightKg: points == 0 ? null : 79.0 - (points - 1) * 0.5,
    weeklyAverageKg: points >= 3 ? 78.5 : null,
    changeKg: points >= 2 ? -(points - 1) * 0.5 : null,
  ),
);

Future<Harness> open(
  WidgetTester tester, {
  int points = 3,
  List<WeightEntry> entries = const [],
}) async {
  await tallScreen(tester);
  final h = Harness();
  h.api.onWeightChart = (period) async => chartOf(period, points: points);
  h.api.onWeightEntries = () async => entries;
  await h.pumpScreen(tester, WeightScreen(registeredAt: DateTime(2026, 11, 1)));
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('cambiar de periodo vuelve a pedir la gráfica', (tester) async {
    final h = await open(tester);
    expect(h.api.chartPeriods, ['p30']);
    await tester.tap(find.text('90 días'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todo'));
    await tester.pumpAndSettle();
    expect(h.api.chartPeriods, ['p30', 'p90', 'all']);
  });

  testWidgets('con 2 o más registros se pinta el gráfico', (tester) async {
    await open(tester);
    expect(find.byType(LineChart), findsOneWidget);
    expect(
      find.text('Necesitas al menos 2 registros para ver la gráfica'),
      findsNothing,
    );
  });

  testWidgets('con menos de 2 registros se ve el mensaje y no el gráfico', (
    tester,
  ) async {
    await open(tester, points: 1);
    expect(
      find.text('Necesitas al menos 2 registros para ver la gráfica'),
      findsOneWidget,
    );
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('el resumen textual y su Semantics están presentes', (
    tester,
  ) async {
    await open(tester);
    expect(find.textContaining('Peso actual: 78,0 kg'), findsOneWidget);
    expect(find.textContaining('Media semanal: 78,5 kg'), findsOneWidget);
    expect(
      find.textContaining('Variación en el periodo: -1,0 kg'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('^Gráfica de peso')), findsOneWidget);
  });

  testWidgets('sin datos de media el resumen lo dice', (tester) async {
    await open(tester, points: 2);
    expect(
      find.textContaining('Media semanal: sin datos suficientes'),
      findsOneWidget,
    );
  });

  testWidgets('la lista de registros acompaña al gráfico', (tester) async {
    await open(
      tester,
      entries: [
        WeightEntry(measuredOn: DateTime(2026, 11, 22), weightKg: 78.0),
      ],
    );
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('78,0 kg'), findsOneWidget);
    expect(find.text('Registros'), findsOneWidget);
  });

  testWidgets('el tamaño de texto grande no desborda', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(
      tester,
      entries: [
        WeightEntry(measuredOn: DateTime(2026, 11, 22), weightKg: 78.0),
      ],
    );
    expect(tester.takeException(), isNull);
  });
}
