import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykcal/core/api/models.dart';
import 'package:mykcal/features/diary/summary_detail_sheet.dart';

import '../helpers/fakes.dart';
import 'summary_card_test.dart' show target2000;

DiaryEntry micros({double? sodium = 1900}) => sampleEntry(
  values: amounts(
    kcal: 500,
    fiberG: 18,
    sodiumMg: sodium,
    potassiumMg: 2000,
    calciumMg: 800,
    ironMg: 6,
    magnesiumMg: 300,
    vitaminDUg: 5,
    vitaminCMg: 60,
  ),
);

Future<void> pumpSheet(WidgetTester tester, DiaryDay day) =>
    Harness().pumpScreen(
      tester,
      Scaffold(
        body: SingleChildScrollView(child: SummaryDetailSheet(day: day)),
      ),
    );

void main() {
  testWidgets('fibra y los 7 micros con consumido y objetivo', (tester) async {
    await pumpSheet(tester, sampleDay(target: target2000, entries: [micros()]));
    expect(find.text('Fibra'), findsOneWidget);
    expect(find.text('18 / 25 g'), findsOneWidget);
    for (final label in [
      'Sodio',
      'Potasio',
      'Calcio',
      'Hierro',
      'Magnesio',
      'Vitamina D',
      'Vitamina C',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('2.000 / 3.500 mg'), findsOneWidget); // potasio
    expect(find.text('5 / 15 µg'), findsOneWidget); // vitamina D
  });

  testWidgets('el sodio es un máximo: máx. y lo que queda hasta el límite', (
    tester,
  ) async {
    await pumpSheet(tester, sampleDay(target: target2000, entries: [micros()]));
    expect(find.text('1.900 mg'), findsOneWidget);
    expect(find.text('máx. 2.300 mg'), findsOneWidget);
    expect(find.text('Quedan 400 mg'), findsOneWidget);
  });

  testWidgets('sodio por encima del límite', (tester) async {
    await pumpSheet(
      tester,
      sampleDay(target: target2000, entries: [micros(sodium: 2600)]),
    );
    expect(find.text('300 mg por encima del límite'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
  });

  testWidgets('los nutrientes incompletos lo dicen y explican por qué', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      sampleDay(
        target: target2000,
        entries: [micros()],
        incomplete: const ['fiber_g', 'iron_mg'],
      ),
    );
    expect(find.text('incompleto'), findsNWidgets(2));
    expect(find.byIcon(Icons.info_outline), findsNWidgets(2));
    expect(
      find.text(
        'Algún alimento de este día no tiene este dato; cuenta como 0.',
      ),
      findsOneWidget,
    );
  });
}
